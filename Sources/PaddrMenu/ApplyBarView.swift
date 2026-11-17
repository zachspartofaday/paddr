import PaddrAppSupport
import SwiftUI

enum PaddrStatusKind: String, CaseIterable, Identifiable {
    case access
    case puck
    case controller
    case output
    case battery

    var id: Self { self }
}

/// The status bar that floats over the bottom of the workspace: connection
/// state, the next step, and the output switch. It is one of the window's two
/// Liquid Glass surfaces; the toolbar is the other.
struct ApplyBarView: View {
    @Bindable var model: PaddrMenuModel
    /// The setup checklist carries the permission controls while it is showing.
    var showsPermissionNotice = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var availableWidth: CGFloat = 0
    @State private var showsConnectionDetails = false
    @State private var showsPermissionSetup = false
    @State private var revealedTransitionGuidance: PaddrReadinessNextAction?

    var outputValue: LocalizedStringResource {
        switch model.readiness.output {
        case .active: "Active"
        case .releasing: "Releasing"
        case .waiting: "Waiting"
        case .idle: "Off"
        }
    }

    private var outputSystemImage: String {
        switch model.readiness.output {
        case .active: "wave.3.right.circle.fill"
        case .releasing: "arrow.down.circle"
        case .waiting: "hourglass.circle"
        case .idle: "pause.circle"
        }
    }

    private var batteryPresentation: BatteryStatusPresentation {
        BatteryStatusPresentation(status: model.batteryStatus)
    }

    private var controllerSummary: LocalizedStringResource {
        model.readiness.controller == .connected
            ? "Controller connected"
            : "Controller not connected"
    }

    private var batteryState: StatusBadgeState {
        switch batteryPresentation.levelBand {
        case .unavailable: .neutral
        case .critical: .critical
        case .low: .problem
        case .healthy: .ready
        }
    }

    var outputToggleAccessibilityLabel: LocalizedStringResource { "Enable output" }

    var outputToggleAccessibilityValue: LocalizedStringResource {
        model.isEnabled ? "On" : "Off"
    }

    var showsPendingSaveHint: Bool { model.hasUnsavedChanges && !model.isEnabled }

    var outputToggleHelp: LocalizedStringResource {
        if let reason = model.readiness.outputDisabledReason {
            if showsPendingSaveHint {
                let message = String(localized: reason.message)
                return "\(message) Turning on saves your pending changes."
            }
            return reason.message
        }
        if showsPendingSaveHint { return "Turning on saves your pending changes." }
        return "Enable or disable output"
    }

    var outputToggleAccessibilityIdentifier: String {
        PaddrAccessibility.identifier("toolbar", "output")
    }

    var permissionDetail: LocalizedStringResource {
        switch model.readiness.access {
        case .bothNeeded: "Input Monitoring and Accessibility are needed. You can keep editing."
        case .inputMonitoringNeeded: "Input Monitoring is needed to read your controller. You can keep editing."
        case .accessibilityNeeded: "Accessibility is needed to send your mapped actions. You can keep editing."
        case .ready: "Access is ready."
        }
    }

    // Normal activation and release settle within a few controller reports.
    // Key the delay by the specific transition so switching between them starts
    // a fresh wait, while failures and permission instructions bypass the delay.
    private var usesExplicitStatusMessage: Bool {
        model.status.messageState != nil && model.status != .waitingForNeutral
    }

    private var pendingTransitionGuidance: PaddrReadinessNextAction? {
        guard !usesExplicitStatusMessage, model.hasSystemAccess else { return nil }
        switch model.readiness.nextAction {
        case .releaseTrackpads, .waitForOutputRelease, .waitForProfileOperation:
            return model.readiness.nextAction
        default:
            return nil
        }
    }

    // Setup is the actionable next step while permissions are missing. Preserve
    // explicit failures and system-prompt instructions, without competing advice.
    var showsStatusMessage: Bool {
        if let pendingTransitionGuidance {
            return revealedTransitionGuidance == pendingTransitionGuidance
        }
        return usesExplicitStatusMessage
            || (model.hasSystemAccess && model.readiness.nextAction != .none
                && model.readiness.nextAction != .connectController
                && model.readiness.nextAction != .enableOutput)
    }

    var body: some View {
        let usesInlineLayout = availableWidth >= PaddrStyle.Metrics.statusBarInlineBreakpoint
            && !dynamicTypeSize.isAccessibilitySize
        let layout = usesInlineLayout
            ? AnyLayout(HStackLayout(alignment: .top, spacing: PaddrStyle.Spacing.s5))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: PaddrStyle.Spacing.s3))

        // One container lets the notice and the status row share sampling and
        // merge as a single piece of glass instead of stacking two effects.
        GlassEffectContainer(spacing: PaddrStyle.Spacing.s2) {
            VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s2) {
                if !model.hasSystemAccess, showsPermissionNotice {
                    permissionNotice.paddrBarSurface()
                }
                layout {
                    VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s2) {
                        hardwareSummary
                        if showsStatusMessage { statusMessage }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: PaddrStyle.Spacing.s1) {
                        HStack(spacing: PaddrStyle.Spacing.s3) {
                            Text(outputValue)
                                .paddrTypography(.caption)
                                .foregroundStyle(model.readiness.output == .active ? PaddrStyle.activeText
                                    : model.readiness.output == .idle ? PaddrStyle.warningText : PaddrStyle.textSecondary)
                                .accessibilityLabel(Text("Output status"))
                                .accessibilityValue(Text(outputValue))
                                .paddrAccessibilityID("status", "output")
                            HStack(spacing: PaddrStyle.Spacing.s2) {
                                // The visible label shares pointer activation with
                                // the switch, which owns the single named AX target.
                                Button("Enable output") { model.isEnabled.toggle() }
                                    .buttonStyle(.plain)
                                    .paddrTypography(.rowLabel)
                                    .focusable(false)
                                    .accessibilityHidden(true)
                                PaddrTuningSwitch(title: outputToggleAccessibilityLabel, isOn: $model.isEnabled,
                                                  accessibilityIdentifier: outputToggleAccessibilityIdentifier,
                                                  help: outputToggleHelp)
                                    // Align the drawn track, excluding its invisible
                                    // focus/hit reservation, with the workspace's trailing edge.
                                    .padding(.trailing, -(PaddrStyle.Width.toggle - PaddrStyle.Control.TuningSwitch.track.width) / 2)
                            }
                            .disabled(!model.canToggleOutput)
                            .help(Text(outputToggleHelp))
                        }
                        .frame(minHeight: PaddrStyle.Control.height)
                        .fixedSize(horizontal: false, vertical: true)
                        if showsPendingSaveHint {
                            Text("Turning on saves your pending changes.")
                                .paddrTypography(.caption)
                                .foregroundStyle(PaddrStyle.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .paddrAccessibilityID("toolbar", "output", "save-hint")
                        }
                    }
                    .frame(maxWidth: usesInlineLayout ? nil : .infinity, alignment: .trailing)
                }
                .paddrBarSurface()
            }
        }
        .padding(.horizontal, PaddrStyle.Bar.margin)
        .padding(.top, PaddrStyle.Spacing.s2)
        .padding(.bottom, PaddrStyle.Bar.margin)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
            guard width > 0 else { return }
            availableWidth = width
        }
        .sheet(isPresented: $showsPermissionSetup) { PermissionSetupView(model: model) }
        .task(id: pendingTransitionGuidance) {
            revealedTransitionGuidance = nil
            guard let guidance = pendingTransitionGuidance else { return }
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch { return }
            guard !Task.isCancelled, pendingTransitionGuidance == guidance else { return }
            revealedTransitionGuidance = guidance
            AccessibilityNotification.Announcement(String(localized: guidance.title)).post()
        }
        .onChange(of: model.status) { _, status in
            guard status.messageState != nil, status != .waitingForNeutral else { return }
            AccessibilityNotification.Announcement(String(localized: status.message)).post()
        }
    }

    private var permissionNotice: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: PaddrStyle.Spacing.s3))
            : AnyLayout(HStackLayout(alignment: .center, spacing: PaddrStyle.Spacing.s4))
        return layout {
            HStack(alignment: .top, spacing: PaddrStyle.Spacing.s3) {
                Image(systemName: "exclamationmark.shield")
                    .foregroundStyle(PaddrStyle.warningText)
                    .paddrTypography(.sectionTitle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s1) {
                    Text("Allow access to use your mappings")
                        .paddrTypography(.sectionLabel)
                    Text(permissionDetail)
                        .paddrTypography(.caption)
                        .foregroundStyle(PaddrStyle.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .paddrAccessibilityID("permissions", "summary")
            Button("Open Setup…") { showsPermissionSetup = true }
                .paddrActionButton(.secondary)
                .fixedSize()
                .paddrAccessibilityID("permissions", "open-setup")
        }
    }

    private var hardwareSummary: some View {
        // Controller connection can precede the first battery report. Reserve
        // its visible status immediately, then replace the unavailable value.
        let showsBattery = model.controllerConnected
        let battery = batteryPresentation
        return PaddrWrappingHStack(horizontalSpacing: PaddrStyle.Spacing.s4, verticalSpacing: PaddrStyle.Spacing.s2) {
            // A control shape separates the one thing here that opens something
            // from the read-only battery value beside it.
            Button { showsConnectionDetails = true } label: {
                HStack(spacing: PaddrStyle.Spacing.s2) {
                    Label(controllerSummary, systemImage: "gamecontroller")
                        .paddrAccessibilityID("status", "controller-summary")
                    Image(systemName: "chevron.down")
                        .imageScale(.small)
                        .foregroundStyle(PaddrStyle.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .paddrActionButton(.secondary)
            .fixedSize()
            .accessibilityLabel("Connection details")
            .accessibilityValue(Text(controllerSummary))
            .help("Connection details")
            .paddrAccessibilityID("status", "details")
            .popover(isPresented: $showsConnectionDetails) { connectionDetails }
            if showsBattery {
                Label {
                    Text("Battery \(battery.compactValue)")
                } icon: {
                    Image(systemName: battery.systemImage)
                        .accessibilityHidden(true)
                }
                .labelStyle(.titleAndIcon)
                .fixedSize()
                // Centre on the connection button in this top-aligned wrapping row.
                .frame(minHeight: PaddrStyle.Control.height)
                .foregroundStyle(batteryState.textColor)
                .accessibilityLabel("Battery")
                .accessibilityValue(Text(verbatim: battery.accessibilityValue))
                .paddrAccessibilityID("status", "battery")
            }
        }
        .paddrTypography(.rowLabel)
    }

    @ViewBuilder private var statusMessage: some View {
        if usesExplicitStatusMessage, let messageState = model.status.messageState {
            Label {
                Text(model.status.message)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(
                    systemName: messageState == .failure
                        ? "exclamationmark.triangle.fill"
                        : "info.circle.fill"
                )
                .accessibilityHidden(true)
            }
            .paddrTypography(.caption)
            .foregroundStyle(
                messageState == .failure ? PaddrStyle.errorText : PaddrStyle.warningText
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.status.message)
            .help(Text(model.status.message))
        } else {
            if showsRefresh {
                // The instruction names this control, so it sits beside it, and
                // drops below when the line would otherwise run out of the bar.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: PaddrStyle.Spacing.s3) {
                        nextActionLabel
                        refreshButton.paddrAccessibilityID("status", "refresh")
                    }
                    VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s2) {
                        nextActionLabel
                        refreshButton.paddrAccessibilityID("status", "refresh")
                    }
                }
            } else {
                nextActionLabel
            }
        }
    }

    private var nextActionLabel: some View {
        Label(
            model.readiness.nextAction.title,
            systemImage: model.readiness.nextAction.systemImage
        )
        .paddrTypography(.caption)
        .foregroundStyle(
            model.readiness.nextAction == .releaseTrackpads
                ? PaddrStyle.warningText
                : PaddrStyle.textSecondary
        )
        // Wraps instead of running past the bar when the line is too long.
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(model.readiness.nextAction.title))
        .help(Text(model.readiness.nextAction.title))
        .paddrAccessibilityID("status", "next-action")
    }

    /// Only a missing puck that nothing is polling for needs a manual refresh.
    var showsRefresh: Bool { model.readiness.nextAction == .refreshPuck }

    private var refreshButton: some View {
        Button("Refresh", action: model.refreshStatus)
            .paddrActionButton(.secondary)
            .fixedSize()
            .help("Refresh controller and permission status")
    }

    private var connectionDetails: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            Text("Connection details")
                .paddrTypography(.sectionTitle)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s2) {
                statusRows
            }
            refreshButton.paddrAccessibilityID("status", "details", "refresh")
        }
        .padding(PaddrStyle.Spacing.s4)
        .foregroundStyle(PaddrStyle.textPrimary)
    }

    @ViewBuilder private var statusRows: some View {
        ForEach(PaddrStatusKind.allCases) { statusRow(for: $0) }
    }

    @ViewBuilder private func statusRow(for kind: PaddrStatusKind) -> some View {
        switch kind {
        case .access:
            let isReady = model.readiness.access == .ready
            StatusDetailRow(
                title: LocalizedStringResource("Access"),
                value: isReady
                    ? LocalizedStringResource("Ready")
                    : LocalizedStringResource("Needed"),
                systemImage: isReady
                    ? "checkmark.shield.fill"
                    : "exclamationmark.shield",
                state: isReady ? .ready : .problem,
                identifier: "access"
            )
        case .puck:
            let isReady = model.readiness.puck == .connected
            StatusDetailRow(
                title: LocalizedStringResource("Puck"),
                value: isReady
                    ? LocalizedStringResource("Connected")
                    : LocalizedStringResource("Not found"),
                systemImage: isReady
                    ? "cable.connector"
                    : "cable.connector.slash",
                state: isReady ? .ready : .problem,
                identifier: "puck"
            )
        case .controller:
            let isReady = model.readiness.controller == .connected
            StatusDetailRow(
                title: LocalizedStringResource("Controller"),
                value: isReady
                    ? LocalizedStringResource("Connected")
                    : LocalizedStringResource("Not found"),
                systemImage: isReady ? "gamecontroller.fill" : "gamecontroller",
                state: isReady ? .ready : .problem,
                identifier: "controller"
            )
        case .output:
            let isReady = model.readiness.output == .active
            StatusDetailRow(
                title: LocalizedStringResource("Output"),
                value: outputValue,
                systemImage: outputSystemImage,
                state: isReady ? .active : .neutral,
                identifier: "output"
            )
        case .battery:
            StatusDetailRow(
                title: LocalizedStringResource("Battery"),
                value: batteryPresentation.compactValue,
                systemImage: batteryPresentation.systemImage,
                state: batteryState,
                accessibilityValue: batteryPresentation.accessibilityValue,
                identifier: "battery"
            )
        }
    }
}
