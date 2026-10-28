import PaddrAppSupport
import PaddrCore
import SwiftUI

/// Controller-wide inputs share the profile draft and the global output gate.
struct ControllerSensorsConfigurationView: View {
    @Environment(\.locale) private var locale
    @Binding var gyro: GyroConfiguration
    @Binding var gripTouch: GripTouchConfiguration
    let sensorStatus: ControllerSensorStatus?
    let isEditable: Bool
    @State private var tuningExpanded: Bool

    init(
        gyro: Binding<GyroConfiguration>,
        gripTouch: Binding<GripTouchConfiguration>,
        sensorStatus: ControllerSensorStatus?,
        isEditable: Bool,
        initialTuningExpanded: Bool = false
    ) {
        _gyro = gyro
        _gripTouch = gripTouch
        self.sensorStatus = sensorStatus
        self.isEditable = isEditable
        _tuningExpanded = State(initialValue: initialTuningExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s4) {
            gripSection
            Divider()
            gyroSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .paddrAccessibilityID("controller-sensors")
    }

    private var gripSection: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            PaddrSectionHeader("Grip touch")
            Text("Hold an action while your hand touches a grip. This senses contact, not squeeze pressure.")
                .paddrTypography(.caption)
                .foregroundStyle(PaddrStyle.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            PaddrAdaptiveSplitView(columnsBreakpoint: 660) {
                gripRow("Left grip", title: "Left grip touch action", selection: $gripTouch.left,
                    touched: sensorStatus?.grips?.leftTouched, identifier: "left")
            } trailing: {
                gripRow("Right grip", title: "Right grip touch action", selection: $gripTouch.right,
                    touched: sensorStatus?.grips?.rightTouched, identifier: "right")
            }
        }
    }

    private func gripRow(
        _ label: LocalizedStringResource,
        title: LocalizedStringResource,
        selection: Binding<String?>,
        touched: Bool?,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s2) {
            HStack(spacing: PaddrStyle.Spacing.s2) {
                Text(label).paddrTypography(.rowLabel)
                Spacer(minLength: PaddrStyle.Spacing.s2)
                Text(ControllerSensorPresentation.gripState(touched))
                    .paddrTypography(.caption)
                    .foregroundStyle(touched == true ? PaddrStyle.action : PaddrStyle.textSecondary)
                    .paddrAccessibilityID("grip", identifier, "state")
            }
            OptionalOutputBindingPicker(selection: selection, title: title,
                accessibilityIdentifier: PaddrAccessibility.identifier("grip", identifier, "action"))
                .disabled(!isEditable)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .paddrAccessibilityID("grip", identifier, "action")
                .help("Touch holds the assigned action; releasing the grip releases it. A grip can also activate gyro aiming.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private var gyroSection: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            PaddrAdaptiveSplitView(columnsBreakpoint: 760) {
                VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s2) {
                    HStack(spacing: PaddrStyle.Spacing.s3) {
                        PaddrSectionHeader("Gyro to mouse")
                        Spacer(minLength: PaddrStyle.Spacing.s2)
                        PaddrTuningSwitch(title: "Gyro to mouse", isOn: $gyro.enabled,
                            accessibilityIdentifier: "paddr.gyro.enabled")
                            .disabled(!isEditable)
                    }
                    Text(ControllerSensorPresentation.gyroState(sensorStatus, configured: gyro.enabled))
                        .paddrTypography(.caption)
                        .foregroundStyle(PaddrStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .paddrAccessibilityID("gyro", "status")
                    Text(gyro.activation == .always
                        ? LocalizedStringResource("On enabling output, hold the controller still to calibrate. Always-on aiming starts after calibration.")
                        : LocalizedStringResource("On enabling output, hold the controller still to calibrate. Release the activation touch, then touch again to aim."))
                        .paddrTypography(.caption)
                        .foregroundStyle(PaddrStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } trailing: {
                VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
                    PaddrSettingsRow(title: "Activate while", systemImage: "hand.point.up") {
                        PaddrMenuPicker(title: "Gyro activation", selection: $gyro.activation,
                            options: GyroActivation.allCases.map {
                                .init(value: $0, title: String(localized: ControllerSensorPresentation.activationTitle($0)))
                            }, accessibilityIdentifier: "paddr.gyro.activation")
                            .paddrAccessibilityID("gyro", "activation")
                    }
                    ValueSliderRow(title: "Gyro sensitivity", systemImage: "scope",
                        value: $gyro.sensitivity, range: ConfigurationLimits.gyroSensitivity, step: 0.1,
                        valueText: ControllerSensorPresentation.sensitivity(gyro.sensitivity, locale: locale), readoutWidth: PaddrStyle.Width.gyroReadout)
                        .paddrAccessibilityID("gyro", "sensitivity")
                }
                .environment(\.paddrStacksSettingLabels, true)
                .frame(width: PaddrStyle.Width.control)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .disabled(!isEditable)
            }
            DisclosureGroup(isExpanded: $tuningExpanded) {
                tuning
                    .padding(.top, PaddrStyle.Spacing.s2)
                    .disabled(!isEditable)
            } label: {
                Button {
                    tuningExpanded.toggle()
                } label: {
                    Text("Gyro tuning")
                        .paddrTypography(.sectionLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityHidden(true)
            }
            .accessibilityLabel(Text("Gyro tuning"))
            .paddrAccessibilityID("gyro", "tuning")
        }
    }

    private var tuning: some View {
        PaddrAdaptiveSplitView(columnsBreakpoint: 760) {
            VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
                ValueSliderRow(title: "Vertical sensitivity", systemImage: "arrow.up.and.down",
                    value: $gyro.verticalScale, range: ConfigurationLimits.gyroVerticalScale, step: 0.1,
                    valueText: gyro.verticalScale.formatted(.number.precision(.fractionLength(1)).locale(locale)) + "×")
                inversionRow("Invert horizontal", value: $gyro.invertHorizontal, identifier: "invert-horizontal")
                inversionRow("Invert vertical", value: $gyro.invertVertical, identifier: "invert-vertical")
            }
            .frame(width: PaddrStyle.Width.control)
            .frame(maxWidth: .infinity, alignment: .trailing)
        } trailing: {
            VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
                ValueSliderRow(title: "Gyro smoothing", systemImage: "waveform.path",
                    value: $gyro.smoothing, range: ConfigurationLimits.gyroSmoothing, step: 0.05,
                    valueText: gyro.smoothing.formatted(.percent.precision(.fractionLength(0)).locale(locale)))
                ValueSliderRow(title: "Noise threshold", systemImage: "waveform.path",
                    value: $gyro.noiseThreshold, range: ConfigurationLimits.gyroNoiseThreshold, step: 0.1,
                    valueText: ControllerSensorPresentation.noise(gyro.noiseThreshold, locale: locale), readoutWidth: PaddrStyle.Width.gyroReadout)
                    .help("Ignores rotation slower than this rate after stationary calibration.")
            }
            .frame(width: PaddrStyle.Width.control)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .environment(\.paddrStacksSettingLabels, true)
    }

    private func inversionRow(_ title: LocalizedStringResource, value: Binding<Bool>, identifier: String) -> some View {
        PaddrSettingsRow(title: title, systemImage: "arrow.left.arrow.right", labelWidth: nil) {
            PaddrTuningSwitch(title: title, isOn: value, accessibilityIdentifier: "paddr.gyro." + identifier)
        }
        .environment(\.paddrStacksSettingLabels, false)
    }
}

enum ControllerSensorPresentation {
    static func gripState(_ touched: Bool?) -> LocalizedStringResource {
        switch touched {
        case true: "Touching"
        case false: "Released"
        case nil: "Unavailable"
        }
    }

    static func activationTitle(_ activation: GyroActivation) -> LocalizedStringResource {
        switch activation {
        case .rightGrip: "Right grip touched"
        case .leftGrip: "Left grip touched"
        case .eitherGrip: "Either grip touched"
        case .eitherPad: "Either trackpad touched"
        case .always: "Always"
        }
    }

    static func gyroState(_ status: ControllerSensorStatus?, configured: Bool) -> LocalizedStringResource {
        guard let status else { return "Motion data unavailable. Connect the controller through the puck." }
        guard status.motionAvailable else { return "Motion data unavailable. Paddr waits for the controller to send it." }
        if !configured { return "Motion data available. Gyro output is off in this draft." }
        return switch status.gyroStatus {
        case .off: "Enable output to calibrate and aim. Save & Apply any changes first."
        case .unavailable: "Waiting for output to arm before calibration."
        case .calibrating: "Calibrating. Keep the controller still."
        case .ready: "Calibrated. Waiting for gyro activation."
        case .active: "Gyro aiming active."
        }
    }

    static func sensitivity(_ value: Double, locale: Locale) -> String {
        let amount = value.formatted(.number.precision(.fractionLength(1)).locale(locale))
        return String(localized: "\(amount) pt/°", locale: locale,
            comment: "Gyro sensitivity in cursor points per degree of controller rotation.")
    }

    static func noise(_ value: Double, locale: Locale) -> String {
        let amount = value.formatted(.number.precision(.fractionLength(1)).locale(locale))
        return String(localized: "\(amount) °/s", locale: locale,
            comment: "Gyro noise threshold in degrees per second.")
    }
}
