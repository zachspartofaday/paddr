import Foundation
import XCTest
@testable import PaddrCore

final class SensorTests: XCTestCase {
    func testEveryReportVariantDecodesGripsAndOptionalSIValues() throws {
        for report: UInt8 in [0x42, 0x45, 0x47] {
            for (mask, left, right): (UInt32, Bool, Bool) in [
                (0, false, false), (0x2000_0000, true, false),
                (0x1000_0000, false, true), (0x3000_0000, true, true)
            ] {
                var bytes = sensorReport(id: report, tick: 65_535, grips: mask)
                writeSensorWord(16_384, into: &bytes, at: 34)
                writeSensorWord(-16_384, into: &bytes, at: 36)
                writeSensorWord(Int16.min, into: &bytes, at: 38)
                writeSensorWord(Int16.max, into: &bytes, at: 40)
                writeSensorWord(Int16.min, into: &bytes, at: 42)
                writeSensorWord(16_384, into: &bytes, at: 44)
                let state = try XCTUnwrap(TritonParser.parseControllerState(bytes, timestampNanoseconds: 99))
                XCTAssertEqual(state.grips, .init(leftTouched: left, rightTouched: right))
                XCTAssertTrue(state.rearButtons.isNeutral)
                let motion = try XCTUnwrap(state.motion)
                XCTAssertEqual(motion.timestampNanoseconds, 99)
                XCTAssertEqual(motion.acceleration.x, 9.80665, accuracy: 1e-8)
                XCTAssertEqual(motion.acceleration.y, -19.6133, accuracy: 1e-8)
                XCTAssertEqual(motion.acceleration.z, 9.80665, accuracy: 1e-8)
                XCTAssertEqual(motion.angularVelocity.x, Double(Int16.max) / 32768 * 2000 * .pi / 180, accuracy: 1e-8)
                XCTAssertEqual(motion.angularVelocity.y, 1000 * .pi / 180, accuracy: 1e-8)
                XCTAssertEqual(motion.angularVelocity.z, 2000 * .pi / 180, accuracy: 1e-8)
                XCTAssertEqual(motion.sensorTimestamp,
                    report == 0x47 ? .ticks32Microseconds(65_535) : .microseconds(65_535))
                let minimum = report == 0x47 ? 32 : 30
                for count in 0...54 {
                    let parsed = TritonParser.parseControllerState(Array(bytes.prefix(count)), timestampNanoseconds: 99)
                    if count < minimum {
                        XCTAssertNil(parsed)
                    } else {
                        XCTAssertEqual(parsed?.grips, state.grips)
                        XCTAssertEqual(parsed?.motion != nil, count >= 46)
                    }
                }
            }
        }
        let zero = try XCTUnwrap(TritonParser.parseControllerState(sensorReport(), timestampNanoseconds: 0)?.motion)
        XCTAssertEqual(zero.angularVelocity, .zero)
        XCTAssertEqual(zero.acceleration, .zero)
    }

    func testTimestampWrapDuplicateBackwardResetAndHostPause() {
        var timeline = MotionTimeline()
        XCTAssertEqual(timeline.accept(sample(tick: .ticks32Microseconds(.max), at: 0)), .first)
        XCTAssertEqual(timeline.accept(sample(tick: .ticks32Microseconds(0), at: 32_000)), .interval(0.000032))
        XCTAssertEqual(timeline.accept(sample(tick: .ticks32Microseconds(0), at: 64_000)), .duplicate)
        XCTAssertEqual(timeline.accept(sample(tick: .ticks32Microseconds(.max), at: 96_000)), .discontinuity)
        timeline.reset()
        XCTAssertEqual(timeline.accept(sample(tick: .microseconds(.max - 15), at: 0)), .first)
        XCTAssertEqual(timeline.accept(sample(tick: .microseconds(16), at: 32_000)), .interval(0.000032))
        XCTAssertEqual(timeline.accept(sample(tick: .microseconds(17), at: 1)), .duplicate)
        XCTAssertEqual(timeline.accept(sample(tick: .microseconds(100), at: 100_032_000)), .discontinuity)
        XCTAssertEqual(timeline.accept(sample(tick: .ticks32Microseconds(101), at: 100_040_000)), .discontinuity)
    }

    func testConfigurationDefaultsValidationNormalizationAndProfileDowngradeProtection() throws {
        for json in ["{}", #"{"gyro":null,"gripTouch":null}"#, #"{"gyro":{},"gripTouch":{}}"#] {
            let config = try JSONDecoder().decode(PaddrConfiguration.self, from: Data(json.utf8)).validated()
            XCTAssertEqual(config.gyro, .init())
            XCTAssertEqual(config.gripTouch, .unassigned)
        }
        var config = PaddrConfiguration.default
        config.gyro = .init(enabled: true, activation: .eitherGrip, sensitivity: 20, verticalScale: 1.5,
                            invertHorizontal: true, invertVertical: true, smoothing: 0.5, noiseThreshold: 2)
        config.gripTouch = .init(left: " F1 ", right: "mouse-left")
        config = try config.validated()
        XCTAssertEqual(config.gripTouch.left, "f1")
        XCTAssertEqual(try JSONDecoder().decode(PaddrConfiguration.self, from: ConfigurationStore.encoded(config)), config)
        for invalid in ["none", "", "no-key", "code:65536"] {
            var copy = config
            copy.gripTouch.right = invalid
            XCTAssertThrowsError(try copy.validated())
        }
        for path in [\GyroConfiguration.sensitivity, \.verticalScale, \.smoothing, \.noiseThreshold] {
            for invalid in [Double.nan, .infinity, -.infinity, -1, 100] {
                var copy = config
                copy.gyro[keyPath: path] = invalid
                XCTAssertThrowsError(try copy.validated())
            }
        }
        for json in [#"{"gyro":{"enabled":true}}"#, #"{"gripTouch":{"left":"f2"}}"#] {
            let decoded = try ConfigurationProfileStore.decodeConfigurationInput(from: Data(json.utf8))
            XCTAssertNil(decoded.profileDocument)
        }
        var document = ConfigurationProfileDocument.default
        let profile = try document.createProfile(named: "Sensors", configuration: config)
        try document.activateProfile(id: profile.id)
        let encoded = try ConfigurationProfileStore.encoded(document)
        XCTAssertEqual(try JSONDecoder().decode(ConfigurationProfileDocument.self, from: encoded), document)
        let legacyBytes = Data(#"{"schemaVersion":1,"activeProfileID":"00000000-0000-0000-0000-000000000001","userProfiles":[]}"#.utf8)
        let migrated = try ConfigurationProfileStore.decodeConfigurationInput(from: legacyBytes)
        XCTAssertEqual(migrated.profileDocument?.schemaVersion, 2)
        XCTAssertEqual(migrated.configuration.gyro, .init())
        var future = document
        future.schemaVersion = 3
        XCTAssertThrowsError(try future.validated())
        // Simulates the schema check in the previous binary, which must reject2.
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNotEqual(raw["schemaVersion"] as? Int, 1)
    }

    func testGripNeutralAdmissionIndependentRearmingAndDuplicateOwnership() throws {
        var mapper = try GripTouchMapper(configuration: .init(left: "space", right: "code:49"))
        XCTAssertFalse(mapper.isNeutral(.init(leftTouched: true)))
        XCTAssertTrue(mapper.process(.init(leftTouched: true, rightTouched: true)).isEmpty)
        XCTAssertTrue(mapper.process(.init()).isEmpty)
        var arbiter = OutputArbiter()
        let key = try KeyCatalog.resolve("space")
        XCTAssertEqual(arbiter.process([.key(key, isPressed: true)], from: .leftPad), [.key(key, isPressed: true)])
        for (source, action) in mapper.process(.init(leftTouched: true, rightTouched: true)) {
            XCTAssertTrue(arbiter.process([action], from: source).isEmpty)
        }
        XCTAssertTrue(arbiter.process([.key(key, isPressed: false)], from: .leftPad).isEmpty)
        for (source, action) in mapper.process(.init(rightTouched: true)) {
            XCTAssertTrue(arbiter.process([action], from: source).isEmpty)
        }
        let reset = mapper.releaseAndReset()
        XCTAssertEqual(reset.count, 1)
        XCTAssertEqual(arbiter.process(reset.map(\.1), from: .rightGrip),
                       [.key(try KeyCatalog.resolve("code:49"), isPressed: false)])
        XCTAssertTrue(mapper.process(.init(rightTouched: true)).isEmpty)
        XCTAssertTrue(mapper.process(.init()).isEmpty)
        XCTAssertEqual(mapper.process(.init(rightTouched: true)).count, 1)
        let unassigned = try GripTouchMapper(configuration: .unassigned)
        XCTAssertTrue(unassigned.isNeutral(.init(leftTouched: true, rightTouched: true)))
    }

    func testGyroCalibrationActivationUnitsInversionAndVerticalScale() throws {
        var configuration = GyroConfiguration(enabled: true, sensitivity: 10, smoothing: 0, noiseThreshold: 0)
        for inverted in [false, true] {
            configuration.invertHorizontal = inverted
            configuration.invertVertical = inverted
            configuration.verticalScale = 2
            var mapper = GyroMapper(configuration: configuration)
            for index in 0...125 {
                XCTAssertTrue(mapper.process(state(index: index), at: UInt64(index) * 4_000_000).isEmpty)
            }
            XCTAssertEqual(mapper.status, .ready)
            XCTAssertTrue(mapper.process(state(index: 126, grips: .init(rightTouched: true)), at: 504_000_000).isEmpty)
            let actions = mapper.process(state(index: 127, rate: SIMD3(.pi / 180, 2 * .pi / 180, 0),
                                               grips: .init(rightTouched: true)), at: 508_000_000)
            guard case let .mouseMove(dx, dy) = try XCTUnwrap(actions.first) else { return XCTFail("Expected mouse movement") }
            XCTAssertEqual(dx, inverted ? 0.08 : -0.08, accuracy: 1e-10)
            XCTAssertEqual(dy, inverted ? 0.08 : -0.08, accuracy: 1e-10)
            XCTAssertEqual(mapper.status, .active)
            XCTAssertTrue(mapper.process(state(index: 128, rate: SIMD3(0, 1, 0)), at: 512_000_000).isEmpty)
            XCTAssertEqual(mapper.status, .ready)
        }
    }

    func testGyroHeldActivationNeedsReleaseAndCalibrationRejectsMotionAndMissingGravity() {
        var mapper = GyroMapper(configuration: .init(enabled: true, smoothing: 0))
        for index in 0...130 {
            let held = state(index: index, grips: .init(rightTouched: true))
            XCTAssertTrue(mapper.process(held, at: UInt64(index) * 4_000_000).isEmpty)
        }
        XCTAssertEqual(mapper.status, .ready)
        XCTAssertTrue(mapper.process(state(index: 131, rate: SIMD3(0, 1, 0), grips: .init(rightTouched: true)), at: 524_000_000).isEmpty)
        XCTAssertTrue(mapper.process(state(index: 132), at: 528_000_000).isEmpty)
        XCTAssertTrue(mapper.process(state(index: 133, grips: .init(rightTouched: true)), at: 532_000_000).isEmpty)
        XCTAssertFalse(mapper.process(state(index: 134, rate: SIMD3(0, 1, 0), grips: .init(rightTouched: true)), at: 536_000_000).isEmpty)
        mapper.reset()
        for index in 0...200 {
            let moving = state(index: index, rate: index == 100 ? SIMD3(0, 1, 0) : .zero)
            XCTAssertTrue(mapper.process(moving, at: UInt64(index) * 4_000_000).isEmpty)
        }
        XCTAssertEqual(mapper.status, .calibrating)
        mapper.reset()
        for index in 0...150 {
            var invalid = state(index: index)
            invalid.motion?.acceleration = .zero
            XCTAssertTrue(mapper.process(invalid, at: UInt64(index) * 4_000_000).isEmpty)
        }
        XCTAssertEqual(mapper.status, .calibrating)
    }

    func testAlwaysActivationNoiseBiasSmoothingAndStaleResetNeverJump() throws {
        let bias = SIMD3<Double>(0.002, 0.003, -0.001)
        var mapper = GyroMapper(configuration: .init(enabled: true, activation: .always, smoothing: 0.5))
        for index in 0...130 { _ = mapper.process(state(index: index, rate: bias), at: UInt64(index) * 4_000_000) }
        XCTAssertEqual(mapper.status, .active)
        XCTAssertTrue(mapper.process(state(index: 131, rate: bias), at: 524_000_000).isEmpty)
        let action = try XCTUnwrap(mapper.process(state(index: 132, rate: bias + SIMD3(0, 1, 0)), at: 528_000_000).first)
        guard case let .mouseMove(dx, _) = action else { return XCTFail("Expected movement") }
        XCTAssertLessThan(abs(dx), 1 * 180 / .pi * 0.004 * 12)
        XCTAssertTrue(mapper.process(state(index: 132, rate: bias + SIMD3(0, 100, 0)), at: 532_000_000).isEmpty)
        mapper.expire(at: 628_000_000)
        XCTAssertEqual(mapper.status, .unavailable)
        XCTAssertTrue(mapper.process(state(index: 133, rate: SIMD3(0, 10, 0)), at: 632_000_000).isEmpty)
        XCTAssertEqual(mapper.status, .unavailable)
        var fresh = state(index: 160, rate: SIMD3(0, 10, 0))
        fresh.motion?.timestampNanoseconds = 640_000_000
        XCTAssertTrue(mapper.process(fresh, at: 640_000_000).isEmpty)
        XCTAssertEqual(mapper.status, .calibrating)
    }

    func testObservationExpiresFrozenMotionButRetainsFreshGripContact() {
        var observation = ControllerSensorObservation()
        let first = state(index: 0, grips: .init(leftTouched: true))
        observation.observe(first, at: 0)
        XCTAssertTrue(observation.motionAvailable)
        for index in 1...30 {
            var repeated = state(index: index, grips: .init(leftTouched: true))
            repeated.motion?.sensorTimestamp = .microseconds(0)
            observation.observe(repeated, at: UInt64(index) * 4_000_000)
            observation.expire(at: UInt64(index) * 4_000_000)
        }
        XCTAssertFalse(observation.motionAvailable)
        XCTAssertEqual(observation.grips, .init(leftTouched: true))
        observation.expire(at: 220_000_000)
        XCTAssertNil(observation.grips)
    }

    func testHoldingAngleProjectsYawAndRollAtFlatDiagonalAndUpright() throws {
        // Independent geometric cases: flat uses yaw, upright uses negative roll,
        // and equal yaw/roll cancel halfway between them.
        let cases: [(angle: Double, yaw: Double, roll: Double, projected: Double)] = [
            (0, 2, 3, 2), (0, 0, 3, 0),
            (45, 2, 2, 0), (45, 1, 0, 0.7071067811865476),
            (45, 0, 1, -0.7071067811865476),
            (90, 2, 3, -3), (90, 2, 0, 0)
        ]
        for sampleCase in cases {
            for inverted in [false, true] {
                var mapper = GyroMapper(configuration: .init(
                    enabled: true, activation: .always, sensitivity: 10, holdingAngleDegrees: sampleCase.angle,
                    invertHorizontal: inverted, invertVertical: inverted, smoothing: 0, noiseThreshold: 0))
                for index in 0...126 {
                    XCTAssertTrue(mapper.process(state(index: index), at: UInt64(index) * 4_000_000).isEmpty)
                }
                let angularRate = SIMD3<Double>(1, sampleCase.yaw, sampleCase.roll) * (.pi / 180)
                let actions = mapper.process(state(index: 127, rate: angularRate), at: 508_000_000)
                guard case let .mouseMove(dx, dy) = try XCTUnwrap(actions.first) else {
                    return XCTFail("Expected projected gyro movement")
                }
                let sign = inverted ? 1.0 : -1.0
                XCTAssertEqual(dx, sign * sampleCase.projected * 0.004 * 10, accuracy: 1e-10)
                XCTAssertEqual(dy, sign * 0.004 * 10, accuracy: 1e-10)
            }
        }
    }

    func testHoldingAngleLegacyDefaultBoundsAndSavedRoundTrip() throws {
        let legacy = try JSONDecoder().decode(PaddrConfiguration.self,
            from: Data(#"{"gyro":{"enabled":true,"sensitivity":9}}"#.utf8))
        XCTAssertEqual(legacy.gyro.holdingAngleDegrees, 0)
        XCTAssertEqual(PaddrConfiguration.default.gyro.holdingAngleDegrees, 0)
        for angle in [0.0, 45.0, 90.0] {
            var configuration = legacy
            configuration.gyro.holdingAngleDegrees = angle
            let raw = try ConfigurationStore.encoded(configuration)
            XCTAssertEqual(try JSONDecoder().decode(PaddrConfiguration.self, from: raw), configuration)
            var document = ConfigurationProfileDocument.default
            let profile = try document.createProfile(named: "Holding angle", configuration: configuration)
            try document.activateProfile(id: profile.id)
            let encoded = try ConfigurationProfileStore.encoded(document)
            let decoded = try ConfigurationProfileStore.decodeConfigurationInput(from: encoded)
            XCTAssertEqual(decoded.configuration.gyro.holdingAngleDegrees, angle)
        }
        for invalid in [-0.01, 90.01, Double.nan, .infinity, -.infinity] {
            var configuration = legacy
            configuration.gyro.holdingAngleDegrees = invalid
            XCTAssertThrowsError(try configuration.validated())
        }
    }

    func testExplicitRecalibrationImmediatelyClearsMotionAndRequiresNewStationaryBiasAndTouchRelease() {
        var mapper = GyroMapper(configuration: .init(enabled: true, smoothing: 0))
        let oldBias = SIMD3<Double>(0.001, 0.002, 0.003)
        for index in 0...130 {
            _ = mapper.process(state(index: index, rate: oldBias), at: UInt64(index) * 4_000_000)
        }
        _ = mapper.process(state(index: 131, rate: oldBias, grips: .init(rightTouched: true)), at: 524_000_000)
        XCTAssertFalse(mapper.process(state(index: 132, rate: oldBias + SIMD3(0, 1, 0),
            grips: .init(rightTouched: true)), at: 528_000_000).isEmpty)
        mapper.beginCalibration(at: 532_000_000, motionAvailable: true)
        XCTAssertEqual(mapper.status, .calibrating)
        for index in 134...140 {
            XCTAssertTrue(mapper.process(state(index: index, rate: SIMD3(0, 1, 0),
                grips: .init(rightTouched: true)), at: UInt64(index) * 4_000_000).isEmpty)
        }
        let newBias = SIMD3<Double>(0.003, -0.004, 0.002)
        for index in 141...271 {
            XCTAssertTrue(mapper.process(state(index: index, rate: newBias,
                grips: .init(rightTouched: true)), at: UInt64(index) * 4_000_000).isEmpty)
        }
        XCTAssertEqual(mapper.status, .ready)
        XCTAssertTrue(mapper.process(state(index: 272, rate: newBias,
            grips: .init(rightTouched: true)), at: 1_088_000_000).isEmpty)
        XCTAssertTrue(mapper.process(state(index: 273, rate: newBias), at: 1_092_000_000).isEmpty)
        XCTAssertTrue(mapper.process(state(index: 274, rate: newBias,
            grips: .init(rightTouched: true)), at: 1_096_000_000).isEmpty)
        XCTAssertTrue(mapper.process(state(index: 275, rate: newBias,
            grips: .init(rightTouched: true)), at: 1_100_000_000).isEmpty)
        XCTAssertFalse(mapper.process(state(index: 276, rate: newBias + SIMD3(0, 1, 0),
            grips: .init(rightTouched: true)), at: 1_104_000_000).isEmpty)
        mapper.beginCalibration(at: 1_108_000_000, motionAvailable: false)
        XCTAssertEqual(mapper.status, .unavailable)
        var disabled = GyroMapper(configuration: .init())
        disabled.beginCalibration(at: 0, motionAvailable: true)
        XCTAssertEqual(disabled.status, .off)
    }

    func testRepeatedRecalibrationRestartsStationaryIntervalAndAlwaysActivationNeedsNoTouch() {
        var mapper = GyroMapper(configuration: .init(enabled: true, activation: .always, smoothing: 0))
        for index in 0...130 { _ = mapper.process(state(index: index), at: UInt64(index) * 4_000_000) }
        XCTAssertEqual(mapper.status, .active)
        mapper.beginCalibration(at: 524_000_000, motionAvailable: true)
        for index in 132...231 {
            XCTAssertTrue(mapper.process(state(index: index), at: UInt64(index) * 4_000_000).isEmpty)
        }
        mapper.beginCalibration(at: 928_000_000, motionAvailable: true)
        for index in 233...363 {
            XCTAssertTrue(mapper.process(state(index: index), at: UInt64(index) * 4_000_000).isEmpty)
        }
        XCTAssertEqual(mapper.status, .active)
        XCTAssertFalse(mapper.process(state(index: 364, rate: SIMD3(0, 1, 0)), at: 1_456_000_000).isEmpty)
    }

    func testRecalibrationIgnoresQueuedSamplesReceivedBeforeTheRequestWasConsumed() {
        var mapper = GyroMapper(configuration: .init(enabled: true, activation: .always, smoothing: 0))
        mapper.beginCalibration(at: 600_000_000, motionAvailable: true)
        // These callbacks are still within the100ms freshness bound, but predate
        // the explicit request and must not count toward its stationary interval.
        for index in 126...150 {
            XCTAssertTrue(mapper.process(state(index: index), at: 600_000_000).isEmpty)
        }
        for index in 151...274 {
            XCTAssertTrue(mapper.process(state(index: index), at: UInt64(index) * 4_000_000).isEmpty)
        }
        XCTAssertEqual(mapper.status, .calibrating)
        XCTAssertTrue(mapper.process(state(index: 275), at: 1_100_000_000).isEmpty)
        XCTAssertEqual(mapper.status, .ready)
    }

    private func sample(tick: TritonMotionTimestamp, at uptime: UInt64) -> TritonMotionSample {
        .init(angularVelocity: .zero, acceleration: SIMD3(0, 9.80665, 0), sensorTimestamp: tick, timestampNanoseconds: uptime)
    }

    private func state(index: Int, rate: SIMD3<Double> = .zero, grips: TritonGripState = .init()) -> TritonControllerState {
        let timestamp = UInt64(index) * 4_000_000
        return .init(pads: .init(
            left: .init(isTouched: false, isClicked: false, x: 0, y: 0, pressure: 0, timestampNanoseconds: timestamp),
            right: .init(isTouched: false, isClicked: false, x: 0, y: 0, pressure: 0, timestampNanoseconds: timestamp)),
            rearButtons: .init(), grips: grips,
            motion: .init(angularVelocity: rate, acceleration: SIMD3(0, 9.80665, 0),
                          sensorTimestamp: .microseconds(UInt32(index * 4000)), timestampNanoseconds: timestamp))
    }
}

private func sensorReport(id: UInt8 = 0x42, tick: UInt32 = 0, grips: UInt32 = 0) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: 54)
    bytes[0] = id
    for offset in 0..<4 { bytes[2 + offset] = UInt8(truncatingIfNeeded: grips >> (offset * 8)) }
    if id == 0x47 {
        for offset in 0..<2 { bytes[32 + offset] = UInt8(truncatingIfNeeded: tick >> (offset * 8)) }
    } else {
        for offset in 0..<4 { bytes[30 + offset] = UInt8(truncatingIfNeeded: tick >> (offset * 8)) }
    }
    return bytes
}

private func writeSensorWord(_ value: Int16, into bytes: inout [UInt8], at offset: Int) {
    let raw = UInt16(bitPattern: value)
    bytes[offset] = UInt8(truncatingIfNeeded: raw)
    bytes[offset + 1] = UInt8(truncatingIfNeeded: raw >> 8)
}
