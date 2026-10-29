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
    @State private var calibrationGuidePresented = false

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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(label)
                    .paddrAccessibilityID("grip", identifier, "label")
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
            sectionHeading("Gyro to mouse", infoTitle: "About gyro aiming",
                message: "Gyro aiming turns controller rotation into mouse movement. Choose a touch for Activation, or Always. Save & Apply changes and enable output, then choose Calibrate. Put the controller down on a stable surface, or hold it still, before starting calibration. With touch activation, release the control after calibration, then touch again to aim. Calibration resets sensor bias without changing your mappings; it requires active output, fresh motion data and no profile operation in progress.",
                identifier: "gyro-info", currentInstruction: gyroState.instruction)
            ControllerSensorSummaryLayout(forceStacked: dynamicTypeSize.isAccessibilitySize) {
                HStack(spacing: PaddrStyle.Spacing.s2) {
                    // The label shares pointer activation; the native switch
                    // remains the only named keyboard/accessibility target.
                    Button("Enable") { gyro.enabled.toggle() }
                        .buttonStyle(.plain)
                        .paddrTypography(.rowLabel)
                        .focusable(false)
                        .accessibilityHidden(true)
                    PaddrTuningSwitch(title: "Gyro to mouse", isOn: $gyro.enabled,
                        accessibilityIdentifier: "paddr.gyro.enabled")
                }
                .disabled(!isEditable)
                HStack(spacing: PaddrStyle.Spacing.s2) {
                    Text(gyroState.title)
                        .paddrTypography(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.trailing)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(gyroState.title)
                        .foregroundStyle(gyroState.isReady ? PaddrStyle.action : PaddrStyle.warningText)
                        .help(gyroState.instruction ?? gyroState.title)
                        .paddrAccessibilityID("gyro", "status")
                    Button {
                        calibrationGuidePresented = true
                    } label: {
                        Text(gyroState.calibrationTitle)
                    }
                    .paddrActionButton(.secondary)
                    .fixedSize()
                    .disabled(!canRecalibrate)
                    .help(calibrationUnavailableReason ?? "Put the controller down on a stable surface, or hold it still, then choose Calibrate.")
                    .paddrAccessibilityID("gyro", "calibrate")
                    .popover(isPresented: $calibrationGuidePresented, arrowEdge: .bottom) {
                        calibrationGuide
                    }
                }
                PaddrAdaptiveHeaderLayout(spacing: PaddrStyle.Spacing.s2,
                    alignsPadInspector: true, forceStacked: dynamicTypeSize.isAccessibilitySize) {
                    Text("Activation").paddrTypography(.rowLabel)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Activation")
                        .paddrAccessibilityID("gyro", "activation-label")
                    PaddrMenuPicker(title: "Gyro activation", selection: $gyro.activation,
                        options: GyroActivation.allCases.map {
                            .init(value: $0, title: String(localized: ControllerSensorPresentation.activationTitle($0)))
                        }, accessibilityIdentifier: "paddr.gyro.activation")
                        .frame(width: PaddrStyle.Width.control)
                        .disabled(!isEditable)
                }
                .frame(maxWidth: .infinity, minHeight: PaddrStyle.Metrics.row, alignment: .leading)
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

    private var calibrationGuide: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            Text("Calibrate Gyro")
                .paddrTypography(.sectionLabel)
                .accessibilityAddTraits(.isHeader)
            Text("Put the controller down on a stable surface, or hold it still. Choose Calibrate, then keep it still until Calibrated, Ready appears.")
                .paddrTypography(.rowLabel)
                .fixedSize(horizontal: false, vertical: true)
                .paddrAccessibilityID("gyro", "calibration-instruction")
            HStack(spacing: PaddrStyle.Spacing.s2) {
                Spacer(minLength: 0)
                Button("Cancel") { calibrationGuidePresented = false }
                    .paddrActionButton(.secondary)
                    .keyboardShortcut(.cancelAction)
                    .paddrAccessibilityID("gyro", "calibration-cancel")
                Button("Calibrate") {
                    guard canRecalibrate else { return }
                    calibrationGuidePresented = false
                    recalibrate()
                }
                .paddrActionButton(.primary)
                .disabled(!canRecalibrate)
                .keyboardShortcut(.defaultAction)
                .paddrAccessibilityID("gyro", "calibration-start")
            }
        }
        .padding(PaddrStyle.Inset.section)
        .frame(idealWidth: 320, maxWidth: 360, alignment: .leading)
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
                sensorSlider("Horizontal sensitivity", value: $gyro.horizontalScale,
                    range: ConfigurationLimits.gyroHorizontalScale, step: 0.1,
                    valueText: gyro.horizontalScale.formatted(.number.precision(.fractionLength(1)).locale(locale)) + "×")
                    .help("Adjusts left and right aiming without changing up and down aiming. Defaults to 2.5×.")
            } trailing: {
                sensorSlider("Vertical sensitivity", value: $gyro.verticalScale,
                    range: ConfigurationLimits.gyroVerticalScale, step: 0.1,
                    valueText: gyro.verticalScale.formatted(.number.precision(.fractionLength(1)).locale(locale)) + "×")
            }
            tuningPair {
                toggleRow("Tilt for horizontal aiming", value: $gyro.horizontalUsesTilt, identifier: "horizontal-tilt",
                    help: "Use side-to-side tilt instead of turning for horizontal aiming. Holding angle applies to both modes; up and down aiming is unchanged.")
            } trailing: {
                toggleRow("Invert horizontal", value: $gyro.invertHorizontal, identifier: "invert-horizontal")
            }
            tuningPair {
                // Nine settings keep complete paired rows; this last left cell is empty.
                Color.clear.frame(height: 0).accessibilityHidden(true).allowsHitTesting(false)
            } trailing: {
                toggleRow("Invert vertical", value: $gyro.invertVertical, identifier: "invert-vertical")
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

    private func toggleRow(
        _ title: LocalizedStringResource, value: Binding<Bool>, identifier: String,
        help: LocalizedStringResource? = nil
    ) -> some View {
        settingRow(title) {
            PaddrTuningSwitch(title: title, isOn: value, accessibilityIdentifier: "paddr.gyro." + identifier, help: help)
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
/// Enable starts the row below the heading. The attached calibration/status group
/// ends on the left inspector; Activation shares the right grip's inspector edges.
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
        for index in subviews.indices {
            let size = row.sizes[index]
            subviews[index].place(at: CGPoint(x: bounds.minX + row.origins[index], y: bounds.midY - size.height / 2),
                anchor: .topLeading, proposal: ProposedViewSize(size))
        }
    }

    private func inlineRow(width: CGFloat, subviews: Subviews) -> (sizes: [CGSize], origins: [CGFloat])? {
        guard !forceStacked, subviews.count == 3,
              let edges = PaddrPadColumns.workspaceInspectorTrailingEdges(in: width) else { return nil }
        var sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let columnWidth = (width - PaddrPadColumns.workspaceSpacing) / 2
        sizes[2] = subviews[2].sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
        guard sizes[2].width <= columnWidth + 0.5 else { return nil }
        let calibrationWidth = edges.left - sizes[0].width - spacing
        guard calibrationWidth > 0 else { return nil }
        if sizes[1].width > calibrationWidth {
            // The status can wrap, but stays beside its fixed-size action.
            sizes[1] = subviews[1].sizeThatFits(ProposedViewSize(width: calibrationWidth, height: nil))
            guard sizes[1].width <= calibrationWidth + 0.5 else { return nil }
        }
        return (sizes, [0, edges.left - sizes[1].width, columnWidth + PaddrPadColumns.workspaceSpacing])
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
                .paddrTypography(.caption)
                .foregroundStyle(PaddrStyle.textSecondary)
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
    var instruction: LocalizedStringResource?
    var isReady = false
    var calibrationTitle: LocalizedStringResource { isReady ? "Calibrate Again" : "Calibrate" }
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
        guard draftEnabled || savedEnabled else { return .init(title: "Off") }
        guard savedEnabled else {
            return .init(title: "Save & Apply needed",
                instruction: "Choose Save & Apply to enable gyro calibration.")
        }
        guard isOutputEnabled else {
            return .init(title: "Calibration needed",
                instruction: status?.motionAvailable == true
                    ? "Enable output, then choose Calibrate."
                    : "Connect the controller, enable output, then choose Calibrate.")
        }
        guard status?.motionAvailable == true else {
            return .init(title: "Motion unavailable",
                instruction: "Connect the controller and wait for fresh motion data.")
        }
        return switch status?.gyroStatus {
        case .calibrating:
            .init(title: "Calibrating—hold still",
                instruction: "Keep the controller still until Calibrated, Ready appears.")
        case .ready:
            .init(title: "Calibrated, Ready", isReady: true)
        case .active:
            .init(title: "Aiming", isReady: true)
        case .calibrationNeeded, .off, .unavailable, nil:
            .init(title: "Calibration needed",
                instruction: "Put the controller down on a stable surface, or hold it still, then choose Calibrate.")
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
