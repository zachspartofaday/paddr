import Foundation

struct GripTouchMapper: Sendable {
    private let leftBinding: HeldOutput?
    private let rightBinding: HeldOutput?
    private var previous = TritonGripState()
    private var leftArmed = false
    private var rightArmed = false

    init(configuration: GripTouchConfiguration) throws {
        leftBinding = try Self.binding(configuration.left)
        rightBinding = try Self.binding(configuration.right)
    }

    func isNeutral(_ grips: TritonGripState) -> Bool {
        (leftBinding == nil || !grips.leftTouched) && (rightBinding == nil || !grips.rightTouched)
    }

    mutating func process(_ grips: TritonGripState) -> [(OutputSource, TrackpadOutputAction)] {
        var result: [(OutputSource, TrackpadOutputAction)] = []
        let leftWasArmed = leftArmed
        let rightWasArmed = rightArmed
        if !grips.leftTouched { leftArmed = true }
        if !grips.rightTouched { rightArmed = true }
        if leftWasArmed, grips.leftTouched != previous.leftTouched, let leftBinding {
            result.append((.leftGrip, Self.action(leftBinding, pressed: grips.leftTouched)))
        }
        if rightWasArmed, grips.rightTouched != previous.rightTouched, let rightBinding {
            result.append((.rightGrip, Self.action(rightBinding, pressed: grips.rightTouched)))
        }
        previous = grips
        return result
    }

    mutating func releaseAndReset() -> [(OutputSource, TrackpadOutputAction)] {
        var releases: [(OutputSource, TrackpadOutputAction)] = []
        if leftArmed, previous.leftTouched, let leftBinding {
            releases.append((.leftGrip, Self.action(leftBinding, pressed: false)))
        }
        if rightArmed, previous.rightTouched, let rightBinding {
            releases.append((.rightGrip, Self.action(rightBinding, pressed: false)))
        }
        previous = .init()
        leftArmed = false
        rightArmed = false
        return releases
    }

    private static func binding(_ value: String?) throws -> HeldOutput? {
        guard let value else { return nil }
        switch value {
        case TapBindingCatalog.leftMouseButton: return .mouseButton(.left)
        case TapBindingCatalog.rightMouseButton: return .mouseButton(.right)
        default: return .key(try KeyCatalog.resolve(value))
        }
    }

    private static func action(_ output: HeldOutput, pressed: Bool) -> TrackpadOutputAction {
        switch output {
        case let .key(key): .key(key, isPressed: pressed)
        case let .mouseButton(button): .mouseButton(button, isPressed: pressed)
        }
    }
}

/// One mapper belongs to one output/controller epoch. It does not own a HID device,
/// task, output sink or persisted calibration. Both elapsed clocks must be fresh.
struct GyroMapper: Sendable {
    private let configuration: GyroConfiguration
    private let calibrationMode: GyroCalibrationMode
    private var calibrationRequested = false
    private var timeline = MotionTimeline()
    private var lastAcceptedUptime: UInt64?
    private var calibrationNotBeforeUptime: UInt64?
    private var calibration = StationaryGyroCalibration()
    private var bias: SIMD3<Double>?
    private var activationReleased = false
    private var wasActive = false
    private var filteredRate = SIMD2<Double>(repeating: 0)
    private(set) var status: GyroStatus

    init(configuration: GyroConfiguration, calibrationMode: GyroCalibrationMode = .onRequest) {
        self.configuration = configuration
        self.calibrationMode = calibrationMode
        status = configuration.enabled ? .unavailable : .off
    }

    mutating func reset() {
        timeline.reset()
        lastAcceptedUptime = nil
        calibrationNotBeforeUptime = nil
        calibrationRequested = false
        calibration = .init()
        bias = nil
        activationReleased = false
        wasActive = false
        filteredRate = .zero
        status = configuration.enabled ? .unavailable : .off
    }

    /// Recalibration changes only this mapper, never output admission or held owners.
    /// The next sample begins a new stationary interval and touch activation must
    /// be freshly released before re-engagement.
    mutating func beginCalibration(at now: UInt64, motionAvailable: Bool) {
        reset()
        if configuration.enabled {
            calibrationNotBeforeUptime = now
            calibrationRequested = true
        }
        if configuration.enabled, motionAvailable {
            lastAcceptedUptime = now
            status = .calibrating
        }
    }

    mutating func expire(at now: UInt64) {
        guard configuration.enabled, !SensorFreshness.isFresh(lastAcceptedUptime, at: now) else { return }
        // Expiry clears the measurement, not the explicit request's admission
        // boundary. A newly drained callback can still predate that request.
        let requestCutoff = calibrationNotBeforeUptime
        let pendingRequest = calibrationRequested && bias == nil
        reset()
        calibrationNotBeforeUptime = requestCutoff
        calibrationRequested = pendingRequest
    }

    mutating func process(_ state: TritonControllerState, at now: UInt64) -> [TrackpadOutputAction] {
        guard configuration.enabled else { return [] }
        let activation = isActivated(state)
        guard let sample = state.motion,
              SensorFreshness.isFresh(sample.timestampNanoseconds, at: now),
              Self.isFinite(sample.angularVelocity), Self.isFinite(sample.acceleration) else {
            expire(at: now)
            return []
        }
        // Buffered callbacks from before an explicit request cannot seed its bias.
        guard calibrationNotBeforeUptime.map({ sample.timestampNanoseconds >= $0 }) ?? true else {
            expire(at: now)
            return []
        }
        let step = timeline.accept(sample)
        let interval: Double
        switch step {
        case .first:
            if !activation { activationReleased = true }
            lastAcceptedUptime = sample.timestampNanoseconds
            status = canMeasureCalibration ? .calibrating : .calibrationNeeded
            if canMeasureCalibration { _ = calibration.process(sample, seconds: 0) }
            return []
        case .duplicate:
            expire(at: now)
            return []
        case .discontinuity:
            // Retain only the new timestamp baseline. No previous integration,
            // calibration, smoothing or activation admission survives a clock reset.
            lastAcceptedUptime = sample.timestampNanoseconds
            // A clock reset invalidates a completed calibration. An explicit
            // measurement still in progress may restart its stationary interval.
            if bias != nil { calibrationRequested = false }
            calibration = .init()
            bias = nil
            activationReleased = !activation
            wasActive = false
            filteredRate = .zero
            status = canMeasureCalibration ? .calibrating : .calibrationNeeded
            if canMeasureCalibration { _ = calibration.process(sample, seconds: 0) }
            return []
        case let .interval(seconds):
            interval = seconds
            lastAcceptedUptime = sample.timestampNanoseconds
        }

        if !activation { activationReleased = true }
        if bias == nil {
            guard canMeasureCalibration else {
                status = .calibrationNeeded
                return []
            }
            bias = calibration.process(sample, seconds: interval)
            if bias != nil { calibrationRequested = false }
            status = bias == nil ? .calibrating : .ready
            wasActive = false
            return []
        }
        guard activation, activationReleased || configuration.activation == .always else {
            wasActive = false
            filteredRate = .zero
            status = .ready
            return []
        }
        status = .active
        guard wasActive else {
            wasActive = true
            filteredRate = .zero
            return []
        }
        let rate = sample.angularVelocity - (bias ?? .zero)
        let degreesPerRadian = 180 / Double.pi
        // SDL axes: positive yaw turns left; positive pitch lifts the nose.
        // Pitching the controller toward upright rotates world yaw between its
        // yaw and roll axes. The orthogonal projection follows side-to-side
        // tilt instead. Both positive world yaw and roll point left; macOS
        // coordinates increase rightward and downward.
        let holdingAngle = configuration.holdingAngleDegrees * Double.pi / 180
        let horizontalRate = configuration.horizontalUsesTilt
            ? rate.y * sin(holdingAngle) + rate.z * cos(holdingAngle)
            : rate.y * cos(holdingAngle) - rate.z * sin(holdingAngle)
        var aim = SIMD2(-horizontalRate, -rate.x) * degreesPerRadian
        if abs(aim.x) < configuration.noiseThreshold { aim.x = 0 }
        if abs(aim.y) < configuration.noiseThreshold { aim.y = 0 }
        if configuration.smoothing == 0 {
            filteredRate = aim
        } else {
            let timeConstant = configuration.smoothing * 0.06
            let alpha = interval / (timeConstant + interval)
            filteredRate += (aim - filteredRate) * alpha
        }
        let dx = filteredRate.x * interval * configuration.sensitivity * (configuration.invertHorizontal ? -1 : 1)
        let dy = filteredRate.y * interval * configuration.sensitivity * configuration.verticalScale
            * (configuration.invertVertical ? -1 : 1)
        guard dx.isFinite, dy.isFinite, dx != 0 || dy != 0 else { return [] }
        return [.mouseMove(dx: dx, dy: dy)]
    }

    private var canMeasureCalibration: Bool {
        calibrationRequested || calibrationMode == .whenStationary
    }

    private func isActivated(_ state: TritonControllerState) -> Bool {
        switch configuration.activation {
        case .rightGrip: state.grips.rightTouched
        case .leftGrip: state.grips.leftTouched
        case .eitherGrip: state.grips.leftTouched || state.grips.rightTouched
        case .eitherPad: state.pads.left.isTouched || state.pads.right.isTouched
        case .always: true
        }
    }

    private static func isFinite(_ vector: SIMD3<Double>) -> Bool {
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    }
}

private struct StationaryGyroCalibration: Sendable {
    private var elapsed: Double = 0
    private var startedAt: UInt64?
    private var count = 0
    private var rateSum = SIMD3<Double>(repeating: 0)
    private var referenceAcceleration: SIMD3<Double>?
    private var referenceRate: SIMD3<Double>?

    mutating func process(_ sample: TritonMotionSample, seconds: Double) -> SIMD3<Double>? {
        let gravity = Self.magnitude(sample.acceleration)
        let maximumRate = 1.5 * Double.pi / 180
        let gravityTolerance = 0.03 * 9.80665
        let rateTolerance = 0.4 * Double.pi / 180
        guard (0.85 * 9.80665...1.15 * 9.80665).contains(gravity),
              Self.magnitude(sample.angularVelocity) <= maximumRate,
              referenceAcceleration.map({ Self.magnitude(sample.acceleration - $0) <= gravityTolerance }) ?? true,
              referenceRate.map({ Self.magnitude(sample.angularVelocity - $0) <= rateTolerance }) ?? true else {
            self = .init()
            return nil
        }
        if referenceAcceleration == nil {
            startedAt = sample.timestampNanoseconds
            referenceAcceleration = sample.acceleration
            referenceRate = sample.angularVelocity
        }
        elapsed += seconds
        count += 1
        rateSum += sample.angularVelocity
        guard elapsed >= 0.5, count >= 50, let startedAt,
              sample.timestampNanoseconds >= startedAt,
              sample.timestampNanoseconds - startedAt >= 500_000_000 else { return nil }
        return rateSum / Double(count)
    }

    private static func magnitude(_ vector: SIMD3<Double>) -> Double {
        sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    }
}
