import Foundation

public struct TrackpadSample: Equatable, Sendable {
    public var isTouched: Bool
    public var isClicked: Bool
    public var x: Int16
    public var y: Int16
    public var pressure: UInt16
    public var timestampNanoseconds: UInt64

    public init(isTouched: Bool, isClicked: Bool, x: Int16, y: Int16, pressure: UInt16, timestampNanoseconds: UInt64) {
        self.isTouched = isTouched
        self.isClicked = isClicked
        self.x = x
        self.y = y
        self.pressure = pressure
        self.timestampNanoseconds = timestampNanoseconds
    }
}

public struct TrackpadPair: Equatable, Sendable {
    public var left: TrackpadSample
    public var right: TrackpadSample
}

public struct TritonRearButtonState: Equatable, Sendable {
    public var l4: Bool
    public var l5: Bool
    public var r4: Bool
    public var r5: Bool

    public init(l4: Bool = false, l5: Bool = false, r4: Bool = false, r5: Bool = false) {
        self.l4 = l4
        self.l5 = l5
        self.r4 = r4
        self.r5 = r5
    }

    public var isNeutral: Bool { !l4 && !l5 && !r4 && !r5 }

    public func isPressed(_ button: RearButton) -> Bool {
        switch button {
        case .l4: l4
        case .l5: l5
        case .r4: r4
        case .r5: r5
        }
    }
}

public struct TritonControllerState: Equatable, Sendable {
    public var pads: TrackpadPair
    public var rearButtons: TritonRearButtonState
    public var grips: TritonGripState
    public var motion: TritonMotionSample?

    public init(
        pads: TrackpadPair,
        rearButtons: TritonRearButtonState,
        grips: TritonGripState = .init(),
        motion: TritonMotionSample? = nil
    ) {
        self.pads = pads
        self.rearButtons = rearButtons
        self.grips = grips
        self.motion = motion
    }
}

public enum ControllerBatteryChargeState: Equatable, Sendable {
    case reset
    case discharging
    case charging
    case sourceValidate
    case chargingDone
    case unknown(UInt8)

    init(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .reset
        case 1: self = .discharging
        case 2: self = .charging
        case 3: self = .sourceValidate
        case 4: self = .chargingDone
        default: self = .unknown(rawValue)
        }
    }
}

public struct ControllerBatteryStatus: Equatable, Sendable {
    public let chargeState: ControllerBatteryChargeState
    public let percentage: UInt8

    public init(chargeState: ControllerBatteryChargeState, percentage: UInt8) {
        self.chargeState = chargeState
        self.percentage = percentage
    }
}

public enum TritonParser {
    private static let rightTouchMask: UInt32 = 0x0020_0000
    private static let rightClickMask: UInt32 = 0x0040_0000
    private static let leftTouchMask: UInt32 = 0x0200_0000
    private static let leftClickMask: UInt32 = 0x0400_0000

    // Wireless-status report IDs and state values follow SDL's ETritonReportIDTypes /
    // ETritonWirelessState (0x46 = ID_TRITON_WIRELESS_STATUS_X, 0x79 = ID_TRITON_WIRELESS_STATUS).
    private static let wirelessStatusReportIDs: Set<UInt8> = [0x46, 0x79]
    private static let wirelessStateDisconnected: UInt8 = 1
    private static let wirelessStateConnected: UInt8 = 2
    private static let batteryStatusReportID: UInt8 = 0x43
    private static let minimumBatteryStatusReportLength = 15

    /// Returns the link state carried by a dongle wireless-status report, or nil when the
    /// bytes are not a wireless-status report with a recognized state.
    public static func parseWirelessConnection(_ bytes: [UInt8]) -> Bool? {
        guard bytes.count >= 2, let report = bytes.first, wirelessStatusReportIDs.contains(report) else { return nil }
        switch bytes[1] {
        case wirelessStateConnected: return true
        case wirelessStateDisconnected: return false
        default: return nil
        }
    }

    /// Parses the packed dongle battery-status report. The report is an ID byte followed by
    /// a 14-byte payload; only charge state and percentage are surfaced by Paddr.
    public static func parseBatteryStatus(_ bytes: [UInt8]) -> ControllerBatteryStatus? {
        guard bytes.count >= minimumBatteryStatusReportLength,
              bytes[0] == batteryStatusReportID,
              bytes[2] <= 100
        else { return nil }
        return ControllerBatteryStatus(
            chargeState: ControllerBatteryChargeState(rawValue: bytes[1]),
            percentage: bytes[2]
        )
    }

    public static func parseTrackpads(_ bytes: [UInt8], timestampNanoseconds: UInt64) -> TrackpadPair? {
        parseControllerState(bytes, timestampNanoseconds: timestampNanoseconds)?.pads
    }

    public static func parseControllerState(
        _ bytes: [UInt8], timestampNanoseconds: UInt64
    ) -> TritonControllerState? {
        guard let report = bytes.first else { return nil }
        let padOffset: Int
        switch report {
        case 0x42, 0x45:
            padOffset = 18
        case 0x47:
            padOffset = 20
        default:
            return nil
        }
        guard bytes.count >= padOffset + 12,
              let buttons = uint32LE(bytes, at: 2),
              let leftX = int16LE(bytes, at: padOffset),
              let leftY = int16LE(bytes, at: padOffset + 2),
              let leftPressure = uint16LE(bytes, at: padOffset + 4),
              let rightX = int16LE(bytes, at: padOffset + 6),
              let rightY = int16LE(bytes, at: padOffset + 8),
              let rightPressure = uint16LE(bytes, at: padOffset + 10)
        else { return nil }

        let pads = TrackpadPair(
            left: TrackpadSample(
                isTouched: buttons & leftTouchMask != 0,
                isClicked: buttons & leftClickMask != 0,
                x: leftX,
                y: leftY,
                pressure: leftPressure,
                timestampNanoseconds: timestampNanoseconds
            ),
            right: TrackpadSample(
                isTouched: buttons & rightTouchMask != 0,
                isClicked: buttons & rightClickMask != 0,
                x: rightX,
                y: rightY,
                pressure: rightPressure,
                timestampNanoseconds: timestampNanoseconds
            )
        )
        return TritonControllerState(
            pads: pads,
            rearButtons: TritonRearButtonState(
                l4: buttons & 0x0002_0000 != 0,
                l5: buttons & 0x0004_0000 != 0,
                r4: buttons & 0x0000_0080 != 0,
                r5: buttons & 0x0000_0100 != 0
            ),
            grips: TritonGripState(
                leftTouched: buttons & 0x2000_0000 != 0,
                rightTouched: buttons & 0x1000_0000 != 0
            ),
            motion: parseMotion(bytes, report: report, timestampNanoseconds: timestampNanoseconds)
        )
    }

    private static func parseMotion(
        _ bytes: [UInt8], report: UInt8, timestampNanoseconds: UInt64
    ) -> TritonMotionSample? {
        // Quaternion bytes are optional and are deliberately not needed for rate aiming.
        guard bytes.count >= 46,
              let ax = int16LE(bytes, at: 34), let ay = int16LE(bytes, at: 36),
              let az = int16LE(bytes, at: 38), let gx = int16LE(bytes, at: 40),
              let gy = int16LE(bytes, at: 42), let gz = int16LE(bytes, at: 44)
        else { return nil }
        let timestamp: TritonMotionTimestamp
        if report == 0x47 {
            guard let ticks = uint16LE(bytes, at: 32) else { return nil }
            timestamp = .ticks32Microseconds(ticks)
        } else {
            guard let ticks = uint32LE(bytes, at: 30) else { return nil }
            timestamp = .microseconds(ticks)
        }
        let gyroScale = 2000.0 * Double.pi / (32768.0 * 180.0)
        let accelerationScale = 2.0 * 9.80665 / 32768.0
        return TritonMotionSample(
            angularVelocity: SIMD3(Double(gx), Double(gz), -Double(gy)) * gyroScale,
            acceleration: SIMD3(Double(ax), Double(az), -Double(ay)) * accelerationScale,
            sensorTimestamp: timestamp,
            timestampNanoseconds: timestampNanoseconds
        )
    }

    private static func uint16LE(_ bytes: [UInt8], at offset: Int) -> UInt16? {
        guard offset >= 0, offset <= bytes.count - 2 else { return nil }
        return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func int16LE(_ bytes: [UInt8], at offset: Int) -> Int16? {
        uint16LE(bytes, at: offset).map { Int16(bitPattern: $0) }
    }

    private static func uint32LE(_ bytes: [UInt8], at offset: Int) -> UInt32? {
        guard offset >= 0, offset <= bytes.count - 4 else { return nil }
        return UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }
}
