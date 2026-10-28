import PaddrAppSupport
import PaddrCore
import SwiftUI

/// Controller-wide inputs share the profile draft and the global output gate.
struct ControllerSensorsConfigurationView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var gyro: GyroConfiguration
    @Binding var gripTouch: GripTouchConfiguration
    let sensorStatus: ControllerSensorStatus?
    let isEditable: Bool
    let isOutputEnabled: Bool
    let savedGyroEnabled: Bool
    let canRecalibrate: Bool
    let calibrationUnavailableReason: LocalizedStringResource?
    let recalibrate: () -> Void
    @State private var tuningExpanded: Bool

    init(
        gyro: Binding<GyroConfiguration>,
        gripTouch: Binding<GripTouchConfiguration>,
        sensorStatus: ControllerSensorStatus?,
        isEditable: Bool,
        initialTuningExpanded: Bool = false,
        isOutputEnabled: Bool = false,
        savedGyroEnabled: Bool = false,
        canRecalibrate: Bool = false,
        calibrationUnavailableReason: LocalizedStringResource? = nil,
        recalibrate: @escaping () -> Void = {}
    ) {
        _gyro = gyro
        _gripTouch = gripTouch
        self.sensorStatus = sensorStatus
        self.isEditable = isEditable
        self.isOutputEnabled = isOutputEnabled
        self.savedGyroEnabled = savedGyroEnabled
        self.canRecalibrate = canRecalibrate
        self.calibrationUnavailableReason = calibrationUnavailableReason
        self.recalibrate = recalibrate
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
            sectionHeading("Grip touch", infoTitle: "About grip touch",
                message: "Touching a grip holds its assigned key or mouse button; releasing it releases that action. This senses hand contact, not squeeze pressure. A grip can also activate gyro aiming.",
                identifier: "grip-info")
            PaddrAdaptiveSplitView(columnsBreakpoint: PaddrStyle.Metrics.padEditorColumnsBreakpoint) {
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
        PaddrAdaptiveHeaderLayout(spacing: PaddrStyle.Spacing.s2,
            alignsPadInspector: true, forceStacked: dynamicTypeSize.isAccessibilitySize) {
            HStack(spacing: PaddrStyle.Spacing.s2) {
                Text(label).paddrTypography(.rowLabel)
                if selection.wrappedValue != nil {
                    Text(ControllerSensorPresentation.gripState(touched))
                        .paddrTypography(.caption)
                        .foregroundStyle(touched == true ? PaddrStyle.action : PaddrStyle.textSecondary)
                        .paddrAccessibilityID("grip", identifier, "state")
                }
            }
            OptionalOutputBindingPicker(selection: selection, title: title,
                accessibilityIdentifier: PaddrAccessibility.identifier("grip", identifier, "action"))
                .disabled(!isEditable)
                .help("Touch holds the assigned action; releasing the grip releases it. A grip can also activate gyro aiming.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var gyroState: GyroPresentation {
        ControllerSensorPresentation.gyroPresentation(sensorStatus,
            draftEnabled: gyro.enabled, savedEnabled: savedGyroEnabled, isOutputEnabled: isOutputEnabled)
    }

    private var gyroSection: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            ControllerSensorSummaryLayout(forceStacked: dynamicTypeSize.isAccessibilitySize) {
                HStack(spacing: PaddrStyle.Spacing.s3) {
                    sectionHeading("Gyro to mouse", infoTitle: "About gyro aiming",
                        message: "Gyro aiming turns controller rotation into mouse movement. Choose a touch to activate it, or Always. Save & Apply changes before enabling output. Keep the controller still for calibration. With touch activation, release the control after enabling output, then touch again to aim. Calibrate Again resets sensor bias without changing your mappings; it requires active output, fresh motion data and no profile operation in progress.",
                        identifier: "gyro-info", currentInstruction: gyroState.instruction)
                    PaddrTuningSwitch(title: "Gyro to mouse", isOn: $gyro.enabled,
                        accessibilityIdentifier: "paddr.gyro.enabled")
                        .disabled(!isEditable)
                }
                Label(gyroState.title, systemImage: gyroState.systemImage)
                    .paddrTypography(.sectionLabel)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(gyroState.title)
                    .foregroundStyle(gyroState.isReady ? PaddrStyle.action : PaddrStyle.textPrimary)
                    .help(gyroState.instruction ?? gyroState.title)
                    .paddrAccessibilityID("gyro", "status")
                Button("Calibrate Again", action: recalibrate)
                    .paddrActionButton(.secondary)
                    .disabled(!canRecalibrate)
                    .help(calibrationUnavailableReason ?? "Keep the controller still while a fresh gyro calibration is measured.")
                    .paddrAccessibilityID("gyro", "calibrate")
                HStack(spacing: PaddrStyle.Spacing.s2) {
                    Text("Activate while").paddrTypography(.rowLabel)
                    PaddrMenuPicker(title: "Gyro activation", selection: $gyro.activation,
                        options: GyroActivation.allCases.map {
                            .init(value: $0, title: String(localized: ControllerSensorPresentation.activationTitle($0)))
                        }, accessibilityIdentifier: "paddr.gyro.activation")
                }
                .disabled(!isEditable)
            }
            .accessibilityElement(children: .contain)
            .paddrAccessibilityID("gyro", "summary")
            DisclosureGroup(isExpanded: $tuningExpanded) {
                tuning
                    .padding(.top, PaddrStyle.Spacing.s2)
                    .disabled(!isEditable)
            } label: {
                Text("Gyro tuning")
                    .paddrTypography(.sectionLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay {
                        // Keep the native text label for disclosure semantics;
                        // extend only pointer activation across the complete row.
                        Button { tuningExpanded.toggle() } label: {
                            Color.clear.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .accessibilityHidden(true)
                    }
            }
            .paddrAccessibilityID("gyro", "tuning")
        }
    }

    private var tuning: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            tuningPair {
                sensorSlider("Gyro sensitivity", value: $gyro.sensitivity,
                    range: ConfigurationLimits.gyroSensitivity, step: 0.1,
                    valueText: ControllerSensorPresentation.sensitivity(gyro.sensitivity, locale: locale),
                    readoutWidth: PaddrStyle.Width.gyroReadout)
            } trailing: {
                sensorSlider("Gyro smoothing", value: $gyro.smoothing,
                    range: ConfigurationLimits.gyroSmoothing, step: 0.05,
                    valueText: gyro.smoothing.formatted(.percent.precision(.fractionLength(0)).locale(locale)))
            }
            tuningPair {
                sensorSlider("Holding angle", value: $gyro.holdingAngleDegrees,
                    range: ConfigurationLimits.gyroHoldingAngle, step: 1,
                    valueText: ControllerSensorPresentation.angle(gyro.holdingAngleDegrees, locale: locale),
                    showsHoldingAngleGuide: true)
                    .help("Match how you hold the controller: 0° is flat and 90° is upright.")
            } trailing: {
                sensorSlider("Noise threshold", value: $gyro.noiseThreshold,
                    range: ConfigurationLimits.gyroNoiseThreshold, step: 0.1,
                    valueText: ControllerSensorPresentation.noise(gyro.noiseThreshold, locale: locale),
                    readoutWidth: PaddrStyle.Width.gyroReadout)
                    .help("Ignores rotation slower than this rate after stationary calibration.")
            }
            tuningPair {
                sensorSlider("Vertical sensitivity", value: $gyro.verticalScale,
                    range: ConfigurationLimits.gyroVerticalScale, step: 0.1,
                    valueText: gyro.verticalScale.formatted(.number.precision(.fractionLength(1)).locale(locale)) + "×")
            } trailing: {
                inversionRow("Invert horizontal", value: $gyro.invertHorizontal, identifier: "invert-horizontal")
            }
            tuningPair {
                // The fourth left cell is intentionally empty: there are seven settings.
                Color.clear.frame(height: 0).accessibilityHidden(true).allowsHitTesting(false)
            } trailing: {
                inversionRow("Invert vertical", value: $gyro.invertVertical, identifier: "invert-vertical")
            }
        }
    }

    private func tuningPair<Leading: View, Trailing: View>(
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) -> some View {
        PaddrAdaptiveSplitView(equalHeightColumnsBreakpoint: PaddrStyle.Metrics.padEditorColumnsBreakpoint,
            spacing: PaddrPadColumns.workspaceSpacing) {
            ControllerSensorTuningCell(content: leading)
        } trailing: {
            ControllerSensorTuningCell(content: trailing)
        }
    }

    private func inversionRow(_ title: LocalizedStringResource, value: Binding<Bool>, identifier: String) -> some View {
        settingRow(title) {
            PaddrTuningSwitch(title: title, isOn: value, accessibilityIdentifier: "paddr.gyro." + identifier)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func sensorSlider(
        _ title: LocalizedStringResource,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueText: String,
        readoutWidth: CGFloat = PaddrStyle.Width.readout,
        showsHoldingAngleGuide: Bool = false
    ) -> some View {
        settingRow(title) {
            VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s1) {
                HStack(spacing: PaddrStyle.Spacing.s2) {
                Slider(value: value.quantized(step: step, in: range), in: range)
                    .frame(minWidth: PaddrStyle.sliderMinimumWidth)
                    .accessibilityLabel(title)
                    .accessibilityValue(valueText)
                Text(valueText)
                    .paddrTypography(.value)
                    .foregroundStyle(PaddrStyle.textSecondary)
                    .frame(width: readoutWidth, alignment: .trailing)
                    .accessibilityHidden(true)
                }
                if showsHoldingAngleGuide {
                    HStack {
                        Text("0° flat")
                        Spacer(minLength: PaddrStyle.Spacing.s2)
                        Text("90° upright")
                    }
                    .paddrTypography(.caption)
                    .foregroundStyle(PaddrStyle.textSecondary)
                }
            }
        }
    }

    private func settingRow<Control: View>(
        _ title: LocalizedStringResource,
        @ViewBuilder control: () -> Control
    ) -> some View {
        PaddrAdaptiveHeaderLayout(spacing: PaddrStyle.Spacing.s2,
            alignsPadInspector: true, forceStacked: dynamicTypeSize.isAccessibilitySize) {
            Text(title).paddrTypography(.rowLabel)
            control().frame(width: PaddrStyle.Width.control)
        }
        .frame(maxWidth: .infinity, minHeight: PaddrStyle.Metrics.row, alignment: .leading)
    }

    private func sectionHeading(
        _ title: LocalizedStringResource,
        infoTitle: LocalizedStringResource,
        message: LocalizedStringResource,
        identifier: String,
        currentInstruction: LocalizedStringResource? = nil
    ) -> some View {
        HStack(spacing: PaddrStyle.Spacing.s1) {
            Text(title).paddrTypography(.sectionLabel).accessibilityAddTraits(.isHeader)
            ControllerSensorInfoButton(title: infoTitle, message: message, identifier: identifier,
                currentInstruction: currentInstruction)
        }
    }
}

/// One mounted control family reflows as whole items. At ordinary widths the
/// activation menu ends on the same bounded edge as the right pad inspector.
private struct ControllerSensorSummaryLayout: Layout {
    let forceStacked: Bool
    private var spacing: CGFloat { PaddrStyle.Spacing.s3 }
    private var wrapping: PaddrWrappingHStack {
        PaddrWrappingHStack(horizontalSpacing: spacing, verticalSpacing: spacing,
            maximumItemsPerRow: forceStacked ? 1 : nil)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? max(0, $0) : nil }
            ?? (PaddrStyle.Metrics.defaultWindowSize.width - 2 * PaddrStyle.Inset.chrome)
        if let row = inlineRow(width: width, subviews: subviews) {
            return CGSize(width: width, height: row.sizes.map(\.height).max() ?? 0)
        }
        return wrapping.sizeThatFits(proposal: ProposedViewSize(width: width, height: nil), subviews: subviews, cache: &cache)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let row = inlineRow(width: bounds.width, subviews: subviews) else {
            wrapping.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &cache)
            return
        }
        var x = bounds.minX
        for index in subviews.indices {
            let size = row.sizes[index]
            let origin = index == subviews.count - 1 ? bounds.minX + row.trailingEdge - size.width : x
            subviews[index].place(at: CGPoint(x: origin, y: bounds.midY - size.height / 2),
                anchor: .topLeading, proposal: ProposedViewSize(size))
            x = origin + size.width + spacing
        }
    }

    private func inlineRow(width: CGFloat, subviews: Subviews) -> (sizes: [CGSize], trailingEdge: CGFloat)? {
        guard !forceStacked, subviews.count == 4 else { return nil }
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let trailingEdge = PaddrPadColumns.workspaceInspectorTrailingEdges(in: width)?.right ?? width
        let required = sizes.reduce(CGFloat.zero) { $0 + $1.width } + spacing * CGFloat(sizes.count - 1)
        guard required <= trailingEdge else { return nil }
        return (sizes, trailingEdge)
    }
}

/// Existing equal-height columns measure each paired tuning row. Centering the
/// smaller cell keeps corresponding labels aligned beside the angle guide.
private struct ControllerSensorTuningCell<Content: View>: View {
    @Environment(\.paddrFillsEqualHeightColumn) private var fillsColumn
    @ViewBuilder let content: () -> Content

    var body: some View {
        content().frame(maxHeight: fillsColumn ? .infinity : nil, alignment: .center)
    }
}

/// A real button keeps the explanatory copy available to keyboard and assistive
/// input as well as hover, without leaving a permanent paragraph in the editor.
struct ControllerSensorInfoButton: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let identifier: String
    var currentInstruction: LocalizedStringResource?
    @State private var isPresented = false

    private var helpText: String {
        guard let currentInstruction else { return String(localized: message) }
        let instruction = String(localized: currentInstruction)
        let explanation = String(localized: message)
        return String(localized: "\(instruction)\n\n\(explanation)",
            comment: "Current gyro instruction followed by its general help text.")
    }

    var body: some View {
        Button { isPresented.toggle() } label: {
            Label(title, systemImage: "info.circle")
                .labelStyle(.iconOnly)
                .paddrTypography(.rowLabel)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .accessibilityLabel(title)
        .help(Text(verbatim: helpText))
        .paddrAccessibilityID(identifier)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
                Text(verbatim: helpText)
                    .paddrTypography(.rowLabel)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Done") { isPresented = false }
                    .paddrActionButton(.secondary)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(PaddrStyle.Inset.section)
            .frame(idealWidth: 320, maxWidth: 360, alignment: .leading)
        }
    }
}

struct GyroPresentation {
    let title: LocalizedStringResource
    let systemImage: String
    var instruction: LocalizedStringResource?
    var isReady = false
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

    static func gyroPresentation(
        _ status: ControllerSensorStatus?, draftEnabled: Bool, savedEnabled: Bool, isOutputEnabled: Bool
    ) -> GyroPresentation {
        guard draftEnabled || savedEnabled else { return .init(title: "Off", systemImage: "power") }
        guard savedEnabled else {
            return .init(title: "Save & Apply needed", systemImage: "square.and.arrow.down",
                instruction: "Choose Save & Apply to enable gyro calibration.")
        }
        guard isOutputEnabled else {
            return .init(title: "Calibration needed", systemImage: "scope",
                instruction: status?.motionAvailable == true
                    ? "Enable output, then hold the controller still."
                    : "Connect the controller, enable output, then hold still.")
        }
        guard status?.motionAvailable == true else {
            return .init(title: "Motion unavailable", systemImage: "gyroscope",
                instruction: "Connect the controller and wait for fresh motion data.")
        }
        return switch status?.gyroStatus {
        case .calibrating:
            .init(title: "Calibrating—hold still", systemImage: "scope",
                instruction: "Keep the controller still until Ready appears.")
        case .ready:
            .init(title: "Calibrated, Ready", systemImage: "checkmark.circle", isReady: true)
        case .active:
            .init(title: "Aiming", systemImage: "scope", isReady: true)
        case .off, .unavailable, nil:
            .init(title: "Calibration needed", systemImage: "scope",
                instruction: "Release assigned controls to activate output, then hold still.")
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

    static func angle(_ value: Double, locale: Locale) -> String {
        let amount = value.formatted(.number.precision(.fractionLength(0)).locale(locale))
        return String(localized: "\(amount)°", locale: locale,
            comment: "Controller holding angle: 0 degrees is flat; 90 degrees is upright.")
    }
}
