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

struct ApplyBarView: View {
    @Bindable var model: PaddrMenuModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var availableWidth: CGFloat = 0
    @State private var showsConnectionDetails = false
    @State private var showsPermissionSetup = false

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

    // Setup is the actionable next step while permissions are missing. Preserve
    // explicit failures and system-prompt instructions, without competing advice.
    var showsStatusMessage: Bool {
        model.status.messageState != nil
            || (model.hasSystemAccess && model.readiness.nextAction != .none
                && model.readiness.nextAction != .enableOutput)
    }

    var body: some View {
        let usesInlineLayout = availableWidth >= PaddrStyle.Metrics.statusBarInlineBreakpoint
            && !dynamicTypeSize.isAccessibilitySize
        let layout = usesInlineLayout
            ? AnyLayout(HStackLayout(alignment: .top, spacing: PaddrStyle.Spacing.s5))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: PaddrStyle.Spacing.s3))

        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            if !model.hasSystemAccess {
                permissionNotice
                Divider()
            }
            layout {
                VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s2) {
                    hardwareSummary
                    if showsStatusMessage { statusMessage }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: usesInlineLayout ? .trailing : .leading, spacing: PaddrStyle.Spacing.s1) {
                    HStack(spacing: PaddrStyle.Spacing.s3) {
                        Text(outputValue)
                            .paddrTypography(.caption)
                            .foregroundStyle(model.readiness.output == .active ? PaddrStyle.activeText : PaddrStyle.textSecondary)
                            .accessibilityLabel(Text("Output status"))
                            .accessibilityValue(Text(outputValue))
                            .paddrAccessibilityID("status", "output")
                        Toggle("Enable output", isOn: $model.isEnabled)
                            .disabled(!model.canToggleOutput)
                            .toggleStyle(.switch)
                            .accessibilityLabel(Text(outputToggleAccessibilityLabel))
                            .accessibilityValue(Text(outputToggleAccessibilityValue))
                            .accessibilityHint(Text(outputToggleHelp))
                            .help(Text(outputToggleHelp))
                            .accessibilityIdentifier(outputToggleAccessibilityIdentifier)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if showsPendingSaveHint {
                        Text("Turning on saves your pending changes.")
                            .paddrTypography(.caption)
                            .foregroundStyle(PaddrStyle.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .paddrAccessibilityID("toolbar", "output", "save-hint")
                    }
                }
            }
        }
        .padding(.horizontal, PaddrStyle.Inset.chrome)
        .padding(.vertical, PaddrStyle.Spacing.s4)
        .background(PaddrStyle.canvas)
        .overlay(alignment: .top) { Divider() }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
            guard width > 0 else { return }
            availableWidth = width
        }
        .sheet(isPresented: $showsPermissionSetup) { PermissionSetupView(model: model) }
        .onChange(of: model.status) { _, status in
            guard status.messageState != nil else { return }
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
            Button("Open setup…") { showsPermissionSetup = true }
                .paddrActionButton(.secondary)
                .fixedSize()
                .paddrAccessibilityID("permissions", "open-setup")
        }
    }

    private var hardwareSummary: some View {
        PaddrWrappingHStack(horizontalSpacing: PaddrStyle.Spacing.s4, verticalSpacing: PaddrStyle.Spacing.s2) {
            Button { showsConnectionDetails = true } label: {
                HStack(spacing: PaddrStyle.Spacing.s2) {
                    Label(controllerSummary, systemImage: "gamecontroller")
                        .paddrAccessibilityID("status", "controller-summary")
                    Image(systemName: "chevron.down")
                        .imageScale(.small)
                        .foregroundStyle(PaddrStyle.textSecondary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, PaddrStyle.Spacing.s1)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Connection details")
            .accessibilityValue(Text(controllerSummary))
            .help("Connection details")
            .paddrAccessibilityID("status", "details")
            .popover(isPresented: $showsConnectionDetails) {
                VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s2) {
                    Text("Connection details")
                        .paddrTypography(.sectionTitle)
                        .accessibilityAddTraits(.isHeader)
                    statusCells
                }
                .padding(PaddrStyle.Spacing.s4)
            }
            if model.batteryStatus != nil {
                Label {
                    Text("Battery \(batteryPresentation.compactValue)")
                } icon: {
                    Image(systemName: batteryPresentation.systemImage)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(batteryState.textColor)
                .accessibilityLabel("Battery")
                .accessibilityValue(Text(verbatim: batteryPresentation.accessibilityValue))
                .paddrAccessibilityID("status", "battery")
            }
        }
        .paddrTypography(.rowLabel)
    }

    @ViewBuilder private var statusMessage: some View {
        if let messageState = model.status.messageState {
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
            Label(
                model.readiness.nextAction.title,
                systemImage: model.readiness.nextAction.systemImage
            )
            .paddrTypography(.caption)
            .foregroundStyle(
                model.readiness.nextAction == .none
                    ? PaddrStyle.activeText
                    : PaddrStyle.textSecondary
            )
            .help(Text(model.readiness.nextAction.title))
            .paddrAccessibilityID("status", "next-action")
        }
    }

    @ViewBuilder private var statusCells: some View {
        ForEach(PaddrStatusKind.allCases) { statusCell(for: $0) }
    }

    @ViewBuilder private func statusCell(for kind: PaddrStatusKind) -> some View {
        switch kind {
        case .access:
            let isReady = model.readiness.access == .ready
            StatusCell(
                title: LocalizedStringResource("Access"),
                value: isReady
                    ? LocalizedStringResource("Ready")
                    : LocalizedStringResource("Needed"),
                systemImage: isReady
                    ? "checkmark.shield.fill"
                    : "exclamationmark.shield",
                state: isReady ? .ready : .problem,
                isCompact: false,
                identifier: "access"
            )
        case .puck:
            let isReady = model.readiness.puck == .connected
            StatusCell(
                title: LocalizedStringResource("Puck"),
                value: isReady
                    ? LocalizedStringResource("Connected")
                    : LocalizedStringResource("Not found"),
                systemImage: isReady
                    ? "cable.connector"
                    : "cable.connector.slash",
                state: isReady ? .ready : .problem,
                isCompact: false,
                identifier: "puck"
            )
        case .controller:
            let isReady = model.readiness.controller == .connected
            StatusCell(
                title: LocalizedStringResource("Controller"),
                value: isReady
                    ? LocalizedStringResource("Connected")
                    : LocalizedStringResource("Not found"),
                systemImage: isReady ? "gamecontroller.fill" : "gamecontroller",
                state: isReady ? .ready : .problem,
                isCompact: false,
                identifier: "controller"
            )
        case .output:
            let isReady = model.readiness.output == .active
            StatusCell(
                title: LocalizedStringResource("Output"),
                value: outputValue,
                systemImage: outputSystemImage,
                state: isReady ? .active : .neutral,
                isCompact: false,
                identifier: "output"
            )
        case .battery:
            StatusCell(
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
