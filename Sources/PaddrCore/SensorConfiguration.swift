import Foundation

public enum GyroActivation: String, Codable, CaseIterable, Sendable {
    case rightGrip = "right-grip"
    case leftGrip = "left-grip"
    case eitherGrip = "either-grip"
    case eitherPad = "either-pad"
    case always
}

/// Profile values are portable. Sensor bias and calibration belong to a runtime epoch.
public struct GyroConfiguration: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var activation: GyroActivation
    /// Mouse points per degree of rotation.
    public var sensitivity: Double
    public var verticalScale: Double
    /// Controller pitch from flat (0°) toward upright (90°), used for horizontal aiming.
    public var holdingAngleDegrees: Double
    /// Use side-to-side roll instead of turning yaw for horizontal aiming.
    public var horizontalUsesTilt: Bool
    public var invertHorizontal: Bool
    public var invertVertical: Bool
    public var smoothing: Double
    /// Angular rates below this magnitude are suppressed, in degrees per second.
    public var noiseThreshold: Double

    public init(
        enabled: Bool = false,
        activation: GyroActivation = .rightGrip,
        sensitivity: Double = 12,
        verticalScale: Double = 1,
        holdingAngleDegrees: Double = 0,
        horizontalUsesTilt: Bool = false,
        invertHorizontal: Bool = false,
        invertVertical: Bool = false,
        smoothing: Double = 0.15,
        noiseThreshold: Double = 0.5
    ) {
        self.enabled = enabled
        self.activation = activation
        self.sensitivity = sensitivity
        self.verticalScale = verticalScale
        self.holdingAngleDegrees = holdingAngleDegrees
        self.horizontalUsesTilt = horizontalUsesTilt
        self.invertHorizontal = invertHorizontal
        self.invertVertical = invertVertical
        self.smoothing = smoothing
        self.noiseThreshold = noiseThreshold
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, activation, sensitivity, verticalScale, holdingAngleDegrees, horizontalUsesTilt
        case invertHorizontal, invertVertical, smoothing, noiseThreshold
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            enabled: try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? false,
            activation: try values.decodeIfPresent(GyroActivation.self, forKey: .activation) ?? .rightGrip,
            sensitivity: try values.decodeIfPresent(Double.self, forKey: .sensitivity) ?? 12,
            verticalScale: try values.decodeIfPresent(Double.self, forKey: .verticalScale) ?? 1,
            holdingAngleDegrees: try values.decodeIfPresent(Double.self, forKey: .holdingAngleDegrees) ?? 0,
            horizontalUsesTilt: try values.decodeIfPresent(Bool.self, forKey: .horizontalUsesTilt) ?? false,
            invertHorizontal: try values.decodeIfPresent(Bool.self, forKey: .invertHorizontal) ?? false,
            invertVertical: try values.decodeIfPresent(Bool.self, forKey: .invertVertical) ?? false,
            smoothing: try values.decodeIfPresent(Double.self, forKey: .smoothing) ?? 0.15,
            noiseThreshold: try values.decodeIfPresent(Double.self, forKey: .noiseThreshold) ?? 0.5
        )
    }

    func validated() throws -> Self {
        for (name, value, range) in [
            ("sensitivity", sensitivity, ConfigurationLimits.gyroSensitivity),
            ("verticalScale", verticalScale, ConfigurationLimits.gyroVerticalScale),
            ("holdingAngleDegrees", holdingAngleDegrees, ConfigurationLimits.gyroHoldingAngle),
            ("smoothing", smoothing, ConfigurationLimits.gyroSmoothing),
            ("noiseThreshold", noiseThreshold, ConfigurationLimits.gyroNoiseThreshold)
        ] {
            guard value.isFinite, range.contains(value) else {
                throw PaddrError.configuration(
                    "Gyro \(name) must be between \(range.lowerBound) and \(range.upperBound)."
                )
            }
        }
        return self
    }
}

public struct GripTouchConfiguration: Codable, Equatable, Sendable {
    public var left: String?
    public var right: String?

    public static let unassigned = Self()

    public init(left: String? = nil, right: String? = nil) {
        self.left = left
        self.right = right
    }
}
