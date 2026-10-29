import Foundation

public struct TritonGripState: Equatable, Sendable {
    public var leftTouched: Bool
    public var rightTouched: Bool

    public init(leftTouched: Bool = false, rightTouched: Bool = false) {
        self.leftTouched = leftTouched
        self.rightTouched = rightTouched
    }
}

public enum TritonMotionTimestamp: Equatable, Sendable {
    case microseconds(UInt32)
    case ticks32Microseconds(UInt16)
}

/// SDL's right-handed sensor coordinates (raw X, raw Z, -raw Y), in SI units.
public struct TritonMotionSample: Equatable, Sendable {
    public var angularVelocity: SIMD3<Double>
    public var acceleration: SIMD3<Double>
    public var sensorTimestamp: TritonMotionTimestamp
    public var timestampNanoseconds: UInt64

    public init(
        angularVelocity: SIMD3<Double>,
        acceleration: SIMD3<Double>,
        sensorTimestamp: TritonMotionTimestamp,
        timestampNanoseconds: UInt64
    ) {
        self.angularVelocity = angularVelocity
        self.acceleration = acceleration
        self.sensorTimestamp = sensorTimestamp
        self.timestampNanoseconds = timestampNanoseconds
    }
}

public enum GyroStatus: Equatable, Sendable {
    case off
    case unavailable
    case calibrationNeeded
    case calibrating
    case ready
    case active
}

/// The app waits for its guided Calibrate action. The headless CLI can explicitly
/// retain stationary-start calibration without adding a second input owner.
public enum GyroCalibrationMode: Sendable {
    case onRequest
    case whenStationary
}

public struct ControllerSensorStatus: Equatable, Sendable {
    public var grips: TritonGripState?
    public var motionAvailable: Bool
    public var gyroStatus: GyroStatus

    public init(grips: TritonGripState? = nil, motionAvailable: Bool = false, gyroStatus: GyroStatus = .off) {
        self.grips = grips
        self.motionAvailable = motionAvailable
        self.gyroStatus = gyroStatus
    }
}

/// A conservative pause bound, independent of the one-second controller-link timeout.
/// Nominal reports are ~4 ms apart; the physical idle/reconnect timing matrix is still
/// an attended acceptance check. Never integrate a longer pause into one mouse move.
enum SensorFreshness {
    static let deadlineNanoseconds: UInt64 = 100_000_000
    static let maximumIntervalSeconds = 0.1

    static func isFresh(_ timestamp: UInt64?, at now: UInt64) -> Bool {
        guard let timestamp, now >= timestamp else { return false }
        return now - timestamp < deadlineNanoseconds
    }
}

/// Timestamp arithmetic happens in the wire timestamp's own width before scaling.
/// Host chronology also rejects replays and bounds pauses across device-clock resets.
struct MotionTimeline: Sendable {
    enum Step: Equatable {
        case first
        case interval(Double)
        case duplicate
        case discontinuity
    }

    private var previous: TritonMotionSample?

    mutating func reset() { previous = nil }

    mutating func accept(_ sample: TritonMotionSample) -> Step {
        guard let prior = previous else {
            previous = sample
            return .first
        }
        guard sample.timestampNanoseconds >= prior.timestampNanoseconds else { return .duplicate }
        let seconds: Double
        switch (prior.sensorTimestamp, sample.sensorTimestamp) {
        case let (.microseconds(before), .microseconds(after)):
            let ticks = after &- before
            if ticks == 0 { return .duplicate }
            seconds = Double(ticks) / 1_000_000
        case let (.ticks32Microseconds(before), .ticks32Microseconds(after)):
            let ticks = after &- before
            if ticks == 0 { return .duplicate }
            seconds = Double(ticks) * 32 / 1_000_000
        default:
            previous = sample
            return .discontinuity
        }
        previous = sample
        guard sample.timestampNanoseconds - prior.timestampNanoseconds < SensorFreshness.deadlineNanoseconds,
              seconds > 0, seconds < SensorFreshness.maximumIntervalSeconds else { return .discontinuity }
        return .interval(seconds)
    }
}

/// Observation has its own lifetime so diagnostics work with output disabled. Only
/// accepted motion ticks renew availability; repeated frozen samples eventually expire.
struct ControllerSensorObservation: Sendable {
    private var timeline = MotionTimeline()
    private(set) var grips: TritonGripState?
    private(set) var lastGripUptime: UInt64?
    private(set) var lastMotionUptime: UInt64?

    mutating func observe(_ state: TritonControllerState, at now: UInt64) {
        if SensorFreshness.isFresh(state.pads.left.timestampNanoseconds, at: now),
           lastGripUptime.map({ state.pads.left.timestampNanoseconds >= $0 }) ?? true {
            grips = state.grips
            lastGripUptime = state.pads.left.timestampNanoseconds
        }
        if let motion = state.motion, SensorFreshness.isFresh(motion.timestampNanoseconds, at: now) {
            switch timeline.accept(motion) {
            case .first, .interval:
                lastMotionUptime = motion.timestampNanoseconds
            case .discontinuity:
                lastMotionUptime = nil
            case .duplicate:
                break
            }
        }
    }

    mutating func expire(at now: UInt64) {
        if !SensorFreshness.isFresh(lastGripUptime, at: now) {
            grips = nil
            lastGripUptime = nil
        }
        if !SensorFreshness.isFresh(lastMotionUptime, at: now) {
            lastMotionUptime = nil
            // Retain the timeline so a frozen tick cannot look like a new sample.
        }
    }

    var motionAvailable: Bool { lastMotionUptime != nil }
}
