import PaddrAppSupport
import PaddrCore
import SwiftUI

/// The window's one bar of commands. The system draws these items on Liquid
/// Glass; Save & Apply is the window's single tinted element.
struct ConfigurationToolbar: ToolbarContent {
    let model: PaddrMenuModel
    let commands: ProfileCommands

    var body: some ToolbarContent {
        // What is being edited sits in the middle as one control; the one commit
        // action stands alone at the trailing edge.
        ToolbarItem(placement: .principal) { ProfileMenu(model: model, commands: commands) }
        ToolbarItem(placement: .primaryAction) { SaveAndApplyButton(model: model) }
    }
}

/// One control for the profile: its name is the label, and the menu holds the
/// profiles to switch to followed by the commands that manage them. A picker
/// and a separate ellipsis menu read as two unrelated controls.
struct ProfileMenu: View {
    let model: PaddrMenuModel
    let commands: ProfileCommands

    var body: some View {
        let picker = ProfilePickerPresentation(model: model)
        let actions = ProfileActionsPresentation(model: model)

        Menu {
            Picker("Profile", selection: selection) {
                ForEach(picker.options) { option in
                    Text(verbatim: option.label).tag(option.id)
                }
            }
            .pickerStyle(.inline)
            ForEach(actions.sections.indices, id: \.self) { index in
                Section {
                    ForEach(actions.sections[index]) { item in
                        Button(role: item.isDestructive ? .destructive : nil) {
                            commands.perform(item.id, in: model)
                        } label: {
                            ProfileActionLabel(item: item)
                        }
                        .disabled(!item.isEnabled)
                        .help(item.disabledReason.map { Text($0) } ?? Text(verbatim: ""))
                    }
                }
            }
        } label: {
            Text(verbatim: picker.selectedLabel)
        }
        // A toolbar cannot wrap a long name; the full name stays in the menu.
        .frame(maxWidth: PaddrStyle.Width.control)
        // The system pill hugs a menu's text; this gives the name the same
        // room at each end that Save & Apply's label has.
        .padding(.horizontal, PaddrStyle.Spacing.s2)
        .disabled(!model.canManageProfiles)
        .accessibilityLabel("Profile")
        .accessibilityValue(Text(verbatim: picker.accessibilityValue))
        .help(model.activeProfileID == .default
            ? Text("Duplicate Default to create an editable profile")
            : Text("Switch, create, duplicate, rename, revert, or delete profiles"))
        .paddrAccessibilityID("profile", "menu")
    }

    private var selection: Binding<ConfigurationProfileID> {
        Binding(
            get: { model.profileSelectionPresentation.selectedProfileID },
            set: { commands.select($0, in: model) }
        )
    }
}

/// A profile command as a menu shows it: symbol, title, and the reason when it
/// is unavailable. A menu shows a second text as the item's subtitle, so the
/// reason is visible and spoken without hovering.
struct ProfileActionLabel: View {
    let item: ProfileActionItem

    var body: some View {
        Image(systemName: item.systemImage)
        Text(item.title)
        if let reason = item.disabledReason { Text(reason) }
    }
}

/// The save state is the standard document cue (the close-button dot and
/// "Edited" beside the title); assistive input also reads it from this button.
struct SaveAndApplyButton: View {
    let model: PaddrMenuModel

    var body: some View {
        Button(action: model.saveAndApply) { SaveAndApplyLabel() }
            .buttonStyle(.glassProminent)
            .tint(PaddrStyle.controlTint)
            .disabled(!model.canSaveAndApply)
            .keyboardShortcut("s", modifiers: .command)
            .accessibilityValue(model.hasUnsavedChanges ? Text("Unsaved changes") : Text("Saved"))
            .help(Text(Self.help(
                canSave: model.canSaveAndApply,
                hasUnsavedChanges: model.hasUnsavedChanges,
                isSaving: model.hasPendingConfigurationPersistence
            )))
            .paddrAccessibilityID("profile", "save-apply")
    }

    /// What the button does, or why it is unavailable.
    static func help(
        canSave: Bool, hasUnsavedChanges: Bool, isSaving: Bool
    ) -> LocalizedStringResource {
        if canSave { return "Save this profile and apply it to output" }
        if !hasUnsavedChanges { return "There are no unsaved changes" }
        return isSaving ? "Wait for the profile operation to finish" : "Saving is unavailable right now"
    }
}

/// On the accent tint the label uses the accent's own foreground: the pairing
/// every selected segment and primary button in the workspace already uses, and
/// the one the contrast tests measure. Disabled and inactive-window states keep
/// the system's dimmed label.
private struct SaveAndApplyLabel: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        if isEnabled, controlActiveState != .inactive {
            Text("Save & Apply").foregroundStyle(PaddrStyle.controlForeground)
        } else {
            Text("Save & Apply")
        }
    }
}
