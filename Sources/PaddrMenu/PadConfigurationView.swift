import AppKit
import SwiftUI
import PaddrCore

enum TapStabilizationPresentation {
    static func toleranceValue(
        points: Double,
        locale: Locale = .current
    ) -> String {
        let pointsText = points.formatted(
            .number
                .precision(.fractionLength(0))
                .locale(locale)
        )
        return String(
            localized: "\(pointsText) pt",
            locale: locale,
            comment: "Tap-stabilization tolerance value; the argument is a distance in points."
        )
    }
}

enum PointerSetting: CaseIterable {
    case sensitivity
    case acceleration
    case smoothing
    case tapStabilization
    case tapRadius
    case tapAction
    case pointerTracking
}

enum PointerTuningPresentation {
    static func summary(configuration: PadConfiguration, locale: Locale = .current) -> String {
        var values: [String] = []
        if configuration.mouseAccelerationEnabled && configuration.mouseAcceleration > 0 {
            let value = configuration.mouseAcceleration.formatted(.percent.precision(.fractionLength(0)).locale(locale))
            values.append(String(localized: "Acceleration \(value)", locale: locale))
        }
        if configuration.pointerSmoothingEnabled {
            let value = configuration.pointerSmoothingStrength.formatted(.percent.precision(.fractionLength(0)).locale(locale))
            values.append(String(localized: "Smoothing \(value)", locale: locale))
        }
        if configuration.tapStabilizationEnabled {
            let value = TapStabilizationPresentation.toleranceValue(points: configuration.tapStabilizationThresholdPoints, locale: locale)
            values.append(String(localized: "Tap stabilization \(value)", locale: locale))
        }
        if configuration.mouseDeadzone > 0 {
            let value = configuration.mouseDeadzone.formatted(.percent.precision(.fractionLength(0)).locale(locale))
            values.append(String(localized: "Tap radius \(value)", locale: locale))
            if configuration.centerTapTrackingMode == .coupled {
                values.append(String(localized: "Pointer dead zone", locale: locale))
            }
        }
        return values.isEmpty
            ? String(localized: "No additional tuning enabled", locale: locale)
            : values.formatted(.list(type: .and).locale(locale))
    }
}

struct PadConfigurationView: View {
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.locale) private var locale

    @State private var tuningExpanded: Bool

    let side: PadSide
    let isEditable: Bool
    @Binding var configuration: PadConfiguration

    init(
        side: PadSide,
        configuration: Binding<PadConfiguration>,
        isEditable: Bool = true,
        initialTuningExpanded: Bool = false
    ) {
        self.side = side
        self.isEditable = isEditable
        _configuration = configuration
        _tuningExpanded = State(initialValue: initialTuningExpanded)
    }

    private var title: LocalizedStringResource { side == .left ? "Left trackpad" : "Right trackpad" }
    private var accelerationEnabled: Binding<Bool> {
        Binding(
            get: { configuration.mouseAccelerationEnabled },
            set: { enabled in
                if enabled && configuration.mouseAcceleration == 0 {
                    configuration.mouseAcceleration = 0.25
                }
                configuration.mouseAccelerationEnabled = enabled
            }
        )
    }

    private var tracksPointerInsideTapRadius: Binding<Bool> {
        Binding(
            get: { configuration.centerTapTrackingMode == .decoupled },
            set: {
                configuration.centerTapTrackingMode = $0 ? .decoupled : .coupled
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            PaddrAdaptiveHeaderLayout(
                spacing: PaddrStyle.Spacing.s2,
                layoutDirection: layoutDirection
            ) {
                Text(title)
                    .paddrTypography(.cardTitle)
                    .foregroundStyle(PaddrStyle.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                PadModePicker(
                    selection: $configuration.mode,
                    accessibilityIdentifier: PaddrAccessibility.identifier(
                        "pad-mode",
                        side.rawValue
                    )
                )
                .frame(width: PaddrStyle.behaviorPickerWidth)
                .disabled(!isEditable)
            }
            .frame(maxWidth: .infinity, minHeight: PaddrStyle.Metrics.row)

            modeSettings
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    @ViewBuilder private var modeSettings: some View {
        switch configuration.mode {
        case .disabled:
            previewSplit() {
                Text("This trackpad will not emit pointer, scroll, or button input.")
                    .paddrTypography(.rowLabel)
                    .foregroundStyle(PaddrStyle.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .mouse:
            previewSplit() {
                PaddrSettingsGroup {
                    sensitivityRow.disabled(!isEditable)
                    TapActionPicker(selection: $configuration.tapKey)
                        .disabled(!isEditable)
                    DisclosureGroup(isExpanded: $tuningExpanded) {
                        PaddrSettingsGroup {
                            pointerSetting(.acceleration)
                            pointerSetting(.smoothing)
                            pointerSetting(.tapStabilization)
                            pointerSetting(.tapRadius)
                            pointerSetting(.pointerTracking)
                        }
                        .padding(.top, PaddrStyle.Spacing.s2)
                        .disabled(!isEditable)
                    } label: {
                        Text("Pointer tuning")
                            .paddrTypography(.sectionLabel)
                    }
                    .paddrAccessibilityID("pad", side.rawValue, "pointer-tuning")
                    if !tuningExpanded {
                        Text(verbatim: PointerTuningPresentation.summary(configuration: configuration, locale: locale))
                            .paddrTypography(.caption)
                            .foregroundStyle(PaddrStyle.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .paddrAccessibilityID("pad", side.rawValue, "pointer-tuning-summary")
                    }
                }
            }

        case .scroll:
            previewSplit() {
                PaddrSettingsGroup {
                    sensitivityRow.disabled(!isEditable)
                    TapActionPicker(selection: $configuration.tapKey)
                        .disabled(!isEditable)
                }
            }

        case .dpad:
            ButtonZoneConfigurationView(configuration: $configuration, isEditable: isEditable)
        }
    }

    @ViewBuilder
    private func pointerSetting(_ setting: PointerSetting) -> some View {
        switch setting {
        case .sensitivity:
            sensitivityRow
        case .acceleration:
            ToggleValueSliderRow(
                title: "Pointer acceleration",
                systemImage: "arrow.up.right.and.arrow.down.left",
                isEnabled: accelerationEnabled,
                value: $configuration.mouseAcceleration,
                range: ConfigurationLimits.mouseAcceleration,
                step: 0.01,
                valueText: configuration.mouseAcceleration.formatted(
                    .percent.precision(.fractionLength(0))
                ),
                accessibilityIdentifier: PaddrAccessibility.identifier("pad", side.rawValue, "pointer-acceleration"),
                sliderAccessibilityLabel: "Pointer Acceleration Strength"
            )
            .help("Higher values increase fast-motion gain. Turning acceleration off keeps your strength setting.")
        case .smoothing:
            ToggleValueSliderRow(
                title: "Pointer smoothing",
                systemImage: "waveform.path",
                isEnabled: $configuration.pointerSmoothingEnabled,
                value: $configuration.pointerSmoothingStrength,
                range: ConfigurationLimits.pointerSmoothingStrength,
                step: 0.05,
                valueText: configuration.pointerSmoothingStrength.formatted(
                    .percent.precision(.fractionLength(0))
                ),
                accessibilityIdentifier: PaddrAccessibility.identifier(
                    "pad",
                    side.rawValue,
                    "pointer-smoothing"
                ),
                sliderAccessibilityLabel: "Pointer Smoothing Strength"
            )
            .help("Smooths slow pointer jitter while preserving fast movement. The slider controls smoothing strength.")
        case .tapAction:
            TapActionPicker(selection: $configuration.tapKey)
        case .tapRadius:
            ValueSliderRow(
                title: "Center tap radius",
                systemImage: "scope",
                value: $configuration.mouseDeadzone,
                range: ConfigurationLimits.mouseDeadzone,
                step: 0.01,
                valueText: configuration.mouseDeadzone.formatted(
                    .percent.precision(.fractionLength(0))
                )
            )
            .help("The radius starts at the pad center. Leaving it cancels the tap. At 0%, taps use the maximum-movement limit.")
        case .pointerTracking:
            PaddrSettingsRow(
                title: "Track pointer inside tap radius",
                systemImage: "cursorarrow.motionlines",
                labelWidth: nil
            ) {
                PaddrTuningSwitch(
                    title: "Track pointer inside tap radius",
                    isOn: tracksPointerInsideTapRadius,
                    accessibilityIdentifier: PaddrAccessibility.identifier("pad", side.rawValue, "pointer-tracking")
                )
                .help("When on, pointer movement continues inside and across the center tap radius. When off, the radius also acts as a pointer dead zone.")
                .paddrAccessibilityID("pad", side.rawValue, "pointer-tracking")
            }
        case .tapStabilization:
            ToggleValueSliderRow(
                title: "Tap stabilization",
                systemImage: "hand.tap",
                isEnabled: $configuration.tapStabilizationEnabled,
                value: $configuration.tapStabilizationThresholdPoints,
                range: ConfigurationLimits.tapStabilizationThresholdPoints,
                step: 1,
                valueText: TapStabilizationPresentation.toleranceValue(
                    points: configuration.tapStabilizationThresholdPoints,
                    locale: locale
                ),
                accessibilityIdentifier: PaddrAccessibility.identifier(
                    "pad",
                    side.rawValue,
                    "tap-stabilization"
                ),
                sliderAccessibilityLabel: "Tap Stabilization Tolerance"
            )
            .help("Keeps the cursor fixed during a tap. Moving beyond the tolerance cancels the tap and resumes pointer tracking.")
        }
    }

    /// Mirrors the Zones map-plus-inspector split so every mode keeps the pad
    /// itself as the card's anchor.
    private func previewSplit(
        @ViewBuilder settings: @escaping () -> some View
    ) -> some View {
        PaddrAdaptiveSplitView(
            breakpoint: PaddrStyle.previewInspectorColumnsBreakpoint,
            leadingWidth: PaddrStyle.Metrics.zoneMapWidth,
            showsDivider: false,
            leading: { previewSection },
            trailing: { settingsSection(settings) }
        )
    }

    private func settingsSection<Settings: View>(
        @ViewBuilder _ settings: () -> Settings
    ) -> some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            settings()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .environment(\.paddrStacksSettingLabels, true)
        .accessibilityElement(children: .contain)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            PadModePreview(mode: configuration.mode, deadzone: configuration.mouseDeadzone)
                .frame(
                    width: PaddrStyle.Metrics.zoneMapWidth,
                    height: PaddrStyle.Metrics.zoneMapHeight
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .help("Mirrors how the trackpad will respond in this mode.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sensitivityRow: some View {
        let isScrollMode = configuration.mode == .scroll
        let value = isScrollMode ? configuration.scrollSensitivity : configuration.sensitivity
        return ValueSliderRow(
            title: "Sensitivity",
            systemImage: "speedometer",
            value: isScrollMode ? $configuration.scrollSensitivity : $configuration.sensitivity,
            range: isScrollMode ? ConfigurationLimits.scrollSensitivity : ConfigurationLimits.sensitivity,
            step: 0.1,
            valueText: value.formatted(.number.precision(.fractionLength(1))) + "×"
        )
    }
}

struct PaddrNativeModePicker: NSViewRepresentable {
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
    @Binding var selection: PadMode
    let accessibilityIdentifier: String

    private static let modes: [PadMode] = [.disabled, .mouse, .scroll, .dpad]
    private static let labels = [
        String(localized: LocalizedStringResource("Off")),
        String(localized: LocalizedStringResource("Pointer")),
        String(localized: LocalizedStringResource("Scroll")),
        String(localized: LocalizedStringResource("Zones"))
    ]

    @MainActor
    final class Coordinator: NSObject {
        var selection: Binding<PadMode>

        init(selection: Binding<PadMode>) {
            self.selection = selection
        }

        @objc func selectionChanged(_ sender: NSSegmentedControl) {
            guard sender.isEnabled, Self.validSegment(sender.selectedSegment) else { return }
            selection.wrappedValue = PaddrNativeModePicker.modes[sender.selectedSegment]
        }

        private static func validSegment(_ segment: Int) -> Bool {
            PaddrNativeModePicker.modes.indices.contains(segment)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> PaddrModeSegmentedControl {
        let control = PaddrModeSegmentedControl(
            labels: Self.labels,
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.selectionChanged(_:))
        )
        control.segmentDistribution = .fillEqually
        control.focusRingType = .none
        control.font = .preferredFont(forTextStyle: .body)
        control.setAccessibilityLabel(String(localized: accessibilityIdentifier.hasSuffix("left")
            ? LocalizedStringResource("Left trackpad behavior") : LocalizedStringResource("Right trackpad behavior")))
        control.cell?.setAccessibilityLabel(control.accessibilityLabel())
        control.cell?.setAccessibilityIdentifier(accessibilityIdentifier)
        control.setAccessibilityIdentifier(accessibilityIdentifier)
        control.identifier = NSUserInterfaceItemIdentifier(accessibilityIdentifier)
        control.controlAppearance = PaddrAppearance(environment: context.environment)
        update(control, coordinator: context.coordinator, isEnabled: context.environment.isEnabled)
        return control
    }

    func updateNSView(_ control: PaddrModeSegmentedControl, context: Context) {
        control.controlAppearance = PaddrAppearance(environment: context.environment)
        update(control, coordinator: context.coordinator, isEnabled: context.environment.isEnabled)
    }

    private func update(_ control: NSSegmentedControl, coordinator: Coordinator, isEnabled: Bool) {
        control.isEnabled = isEnabled
        let bodyFont = NSFont.preferredFont(forTextStyle: .body)
        control.font = NSFont(descriptor: bodyFont.fontDescriptor, size: bodyFont.pointSize * textScale) ?? bodyFont
        control.invalidateIntrinsicContentSize()
        control.needsDisplay = true
        coordinator.selection = $selection
        control.selectedSegment = Self.modes.firstIndex(where: { $0.rawValue == selection.rawValue }) ?? 0
        let segmentWidth = PaddrStyle.behaviorPickerWidth / CGFloat(Self.modes.count)
        for segment in Self.modes.indices {
            control.setWidth(segmentWidth, forSegment: segment)
        }
    }
}

/// Native select-one segments retain their radio-group AX children and tracking.
/// The bespoke drawing uses the same equal segment positions for pointer and keys.
final class PaddrModeSegmentedControl: NSSegmentedControl {
    private(set) var hoveredSegment: Int?
    private(set) var pressedSegment: Int?
    var controlAppearance = PaddrAppearance() { didSet { needsDisplay = true } }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        paddrUpdateHoverTracking()
        // Reconcile stationary pointers after reflow; gaps and outer edges aren't segments.
        if let window { updateHover(at: convert(window.mouseLocationOutsideOfEventStream, from: nil)) }
    }
    func segment(at point: CGPoint) -> Int? {
        guard isEnabled else { return nil }
        return (0..<segmentCount).first { isEnabled(forSegment: $0) && segmentRect($0).contains(point) }
    }
    func updateHover(at point: CGPoint) { hoveredSegment = segment(at: point); needsDisplay = true }
    override func mouseEntered(with event: NSEvent) { updateHover(at: convert(event.locationInWindow, from: nil)) }
    override func mouseMoved(with event: NSEvent) { updateHover(at: convert(event.locationInWindow, from: nil)) }
    override func mouseExited(with event: NSEvent) { hoveredSegment = nil; needsDisplay = true }
    override func mouseDown(with event: NSEvent) {
        pressedSegment = segment(at: convert(event.locationInWindow, from: nil))
        needsDisplay = true
        defer { pressedSegment = nil; needsDisplay = true }
        super.mouseDown(with: event)
    }
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsetsZero }
    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
            super.keyDown(with: event)
            return
        }
        let offset: Int
        switch event.keyCode {
        case 123, 126: offset = -1
        case 124, 125: offset = 1
        case 49: return // The select-one group's current item is already selected.
        default: super.keyDown(with: event); return
        }
        let next = min(max(selectedSegment + offset, 0), segmentCount - 1)
        guard next != selectedSegment, isEnabled(forSegment: next) else { return }
        selectedSegment = next
        needsDisplay = true
        _ = sendAction(action, to: target)
    }
    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize {
        let textHeight = (0..<segmentCount).map {
            PaddrControlDrawing.height(label(forSegment: $0) ?? "", width: (PaddrStyle.behaviorPickerWidth - 10) / 4 - 4,
                font: font ?? .preferredFont(forTextStyle: .body))
        }.max() ?? 16
        return NSSize(width: PaddrStyle.behaviorPickerWidth, height: max(PaddrStyle.Control.height, textHeight + 12))
    }
    func segmentRect(_ index: Int) -> CGRect {
        let inset = PaddrStyle.Control.segmentInset
        let width = (bounds.width - 2 * inset - CGFloat(max(0, segmentCount - 1)) * inset) / CGFloat(max(1, segmentCount))
        return CGRect(x: inset + CGFloat(index) * (width + inset), y: inset,
                      width: width, height: bounds.height - 2 * inset)
    }
    override func becomeFirstResponder() -> Bool { needsDisplay = true; return super.becomeFirstResponder() }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return super.resignFirstResponder() }
    override func draw(_ dirtyRect: NSRect) {
        drawChrome()
    }
    private func drawChrome() {
        if !controlAppearance.usesControlGlass {
            PaddrControlDrawing.fill(bounds, radius: PaddrStyle.Control.radius, color: PaddrStyle.workspace)
        }
        PaddrControlDrawing.stroke(bounds, radius: PaddrStyle.Control.radius,
            color: isEnabled ? PaddrStyle.textSecondary : PaddrStyle.boundary,
            width: controlAppearance.hasIncreasedContrast ? 2 : 1.5)
        for index in 0..<segmentCount {
            let rect = segmentRect(index)
            let selected = isSelected(forSegment: index)
            let enabled = isEnabled && isEnabled(forSegment: index)
            if selected {
                PaddrControlDrawing.fill(rect, radius: PaddrStyle.Control.segmentRadius,
                    color: enabled ? PaddrStyle.controlTint : PaddrStyle.boundary)
            }
            if enabled && (hoveredSegment == index || pressedSegment == index) {
                PaddrControlDrawing.fill(rect, radius: PaddrStyle.Control.segmentRadius,
                    color: pressedSegment == index ? PaddrStyle.controlPressed : PaddrStyle.controlHover)
            }
            PaddrControlDrawing.text(label(forSegment: index) ?? "", rect: rect.insetBy(dx: 2, dy: 2),
                font: font ?? .preferredFont(forTextStyle: .body),
                color: selected ? (enabled ? PaddrStyle.controlForeground : PaddrStyle.textPrimary)
                    : (enabled ? PaddrStyle.textPrimary : PaddrStyle.textSecondary), alignment: .center)
        }
        PaddrControlDrawing.focus(self, rect: bounds, radius: PaddrStyle.Control.radius)
    }
}

struct PadModePicker: View {
    @Binding var selection: PadMode
    let accessibilityIdentifier: String
    var body: some View {
        PaddrNativeModePicker(selection: $selection, accessibilityIdentifier: accessibilityIdentifier)
            .paddrControlMaterial()
    }
}
