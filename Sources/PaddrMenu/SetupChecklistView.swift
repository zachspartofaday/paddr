import PaddrAppSupport
import SwiftUI

/// First-run setup inside the configuration window. Each step shows its state
/// from the readiness resolver and offers its action in place.
struct SetupChecklistView: View {
    let model: PaddrMenuModel
    let commands: ProfileCommands
    /// Called when output becomes active, whether or not the checklist is then dismissed.
    var onComplete: @MainActor () -> Void = {}
    let onDismiss: @MainActor (OnboardingDismissal) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var checklist: PaddrSetupChecklist {
        PaddrSetupChecklist(
            readiness: model.readiness,
            editsOwnProfile: model.activeProfileID != .default
        )
    }

    var body: some View {
        let checklist = checklist

        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s4) {
            header(isComplete: checklist.isComplete)
            ForEach(checklist.items) { item in
                PaddrInsetDivider()
                step(item, in: checklist)
            }
        }
        .paddrCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Set up Paddr")
        .paddrAccessibilityID("setup")
        .onChange(of: checklist.isComplete, initial: true) { _, isComplete in
            if isComplete { onComplete() }
        }
    }

    private func header(isComplete: Bool) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: PaddrStyle.Spacing.s3))
            : AnyLayout(HStackLayout(alignment: .top, spacing: PaddrStyle.Spacing.s4))

        return layout {
            VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s1) {
                Text("Set up Paddr")
                    .paddrTypography(.cardTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("Use Steam Controller trackpads without Steam Input. Paddr maps trackpad gestures to normal macOS mouse, scrolling, and keyboard input; it does not inject into games.")
                    .paddrTypography(.caption)
                    .foregroundStyle(PaddrStyle.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("You can reopen this from Help > Paddr Guide.")
                    .paddrTypography(.caption)
                    .foregroundStyle(PaddrStyle.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(isComplete ? "Done" : "Skip Setup") {
                onDismiss(isComplete ? .completed : .skipped)
            }
            .paddrActionButton(.secondary)
            .fixedSize()
            .paddrAccessibilityID("setup", "dismiss")
        }
    }

    private func step(_ item: PaddrSetupChecklist.Item, in checklist: PaddrSetupChecklist) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PaddrStyle.Spacing.s3) {
            Image(systemName: Self.symbol(for: item.state))
                .foregroundStyle(Self.color(for: item.state))
                .paddrTypography(.sectionLabel)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s2) {
                Text(Self.title(for: item.step))
                    .paddrTypography(.sectionLabel)
                detail(for: item, nextAction: checklist.nextAction)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(Self.title(for: item.step)))
        .accessibilityValue(Text(Self.stateDescription(for: item.state)))
        .paddrAccessibilityID("setup", Self.identifier(for: item.step))
    }

    @ViewBuilder
    private func detail(
        for item: PaddrSetupChecklist.Item, nextAction: PaddrReadinessNextAction
    ) -> some View {
        switch (item.step, item.state == .done) {
        case (.access, true):
            caption("Input Monitoring and Accessibility are allowed.")
        case (.access, false):
            caption("Allow Paddr to read your controller and send your mapped actions. You can edit profiles before granting access.")
            PermissionSetupContent(model: model, identifierPrefix: "setup")
        case (.connection, true):
            caption("The puck and controller are connected.")
        case (.connection, false):
            connectionDetail
        case (.profile, true):
            caption("You’re editing your own profile. Default stays as a read-only reference.")
        case (.profile, false):
            ReadOnlyProfileNotice(model: model, commands: commands)
        case (.output, true):
            caption("Output is active.")
        case (.output, false):
            outputDetail(nextAction: nextAction)
        }
    }

    @ViewBuilder private var connectionDetail: some View {
        // The resolver's own answer, so this step and the status bar always agree.
        let guidance = model.readiness.connectionAction ?? .connectController
        caption(guidance.title)
        if guidance == .refreshPuck {
            Button("Refresh", action: model.refreshStatus)
                .paddrActionButton(.secondary)
                .help("Refresh controller and permission status")
                .paddrAccessibilityID("setup", "refresh")
        }
    }

    @ViewBuilder
    private func outputDetail(nextAction: PaddrReadinessNextAction) -> some View {
        if !model.isEnabled {
            if let reason = model.readiness.outputDisabledReason {
                // The button below is unavailable, so say why instead of asking for it.
                caption(reason.message)
            } else {
                caption("Turn on output, then release both trackpads so mapped input starts from neutral.")
            }
        } else if nextAction.setupStep == .output || nextAction.setupStep == nil {
            caption(nextAction.title, isWarning: nextAction == .releaseTrackpads)
        } else {
            caption("Output is on. It starts once the steps above are done.")
        }
        if !model.isEnabled {
            // Turning on output saves the draft, as the switch in the bar says.
            if model.hasUnsavedChanges {
                caption("Turning on saves your pending changes.")
                    .paddrAccessibilityID("setup", "enable-output", "save-hint")
            }
            enableOutputButton
        }
    }

    @ViewBuilder private var enableOutputButton: some View {
        let button = Button("Enable Output") { model.isEnabled = true }
            .paddrActionButton(.secondary)
            .disabled(!model.canToggleOutput)
            .paddrAccessibilityID("setup", "enable-output")
        if let help = Self.enableOutputHelp(
            disabledReason: model.readiness.outputDisabledReason,
            savesPendingChanges: model.hasUnsavedChanges
        ) {
            button.help(Text(help))
        } else {
            button
        }
    }

    /// Why the button is unavailable, or what it does beyond its title. `nil`
    /// when the title says it all.
    static func enableOutputHelp(
        disabledReason: PaddrOutputDisabledReason?,
        savesPendingChanges: Bool
    ) -> LocalizedStringResource? {
        if let disabledReason { return disabledReason.message }
        return savesPendingChanges ? "Turning on saves your pending changes." : nil
    }

    private func caption(_ text: LocalizedStringResource, isWarning: Bool = false) -> some View {
        Text(text)
            .paddrTypography(.caption)
            .foregroundStyle(isWarning ? PaddrStyle.warningText : PaddrStyle.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    static func title(for step: PaddrSetupStep) -> LocalizedStringResource {
        switch step {
        case .access: "Allow access"
        case .connection: "Connect your controller"
        case .profile: "Create your own profile"
        case .output: "Enable output"
        }
    }

    static func identifier(for step: PaddrSetupStep) -> String {
        switch step {
        case .access: "access"
        case .connection: "connection"
        case .profile: "profile"
        case .output: "output"
        }
    }

    /// The symbol differs for every state, so progress never depends on colour.
    static func symbol(for state: PaddrSetupStepState) -> String {
        switch state {
        case .done: "checkmark.circle.fill"
        case .current: "arrow.forward.circle.fill"
        case .pending: "circle"
        }
    }

    static func color(for state: PaddrSetupStepState) -> Color {
        switch state {
        case .done: StatusBadgeState.ready.color
        case .current: PaddrStyle.accentText
        case .pending: PaddrStyle.textSecondary
        }
    }

    static func stateDescription(for state: PaddrSetupStepState) -> LocalizedStringResource {
        switch state {
        case .done: "Done"
        case .current: "Next step"
        case .pending: "Not done"
        }
    }
}
