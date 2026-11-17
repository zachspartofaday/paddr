import Observation
import PaddrAppSupport
import PaddrCore
import SwiftUI

enum ProfileAction: Hashable, CaseIterable {
    case new
    case duplicate
    case rename
    case revertToSaved
    case restoreDefaults
    case delete
}

struct ProfileActionItem: Identifiable {
    let id: ProfileAction
    let title: LocalizedStringResource
    let systemImage: String
    let isEnabled: Bool
    var isDestructive = false
    /// Why the command is unavailable. Always nil for an enabled command.
    let disabledReason: LocalizedStringResource?
}

/// The profile actions menu as data, so every disabled command carries the
/// reason the interface shows for it.
struct ProfileActionsPresentation {
    let sections: [[ProfileActionItem]]

    var items: [ProfileActionItem] { sections.flatMap { $0 } }

    func item(_ action: ProfileAction) -> ProfileActionItem? {
        items.first { $0.id == action }
    }

    init(
        isDefaultProfile: Bool,
        hasUnsavedChanges: Bool,
        canEditActiveProfile: Bool,
        canRevertToSaved: Bool
    ) {
        let draftReason: LocalizedStringResource? = hasUnsavedChanges
            ? "Save or revert your changes first" : nil
        let editReason: LocalizedStringResource? = canEditActiveProfile ? nil
            : isDefaultProfile ? "Default is read-only" : "Wait for the profile operation to finish"

        let create = ProfileActionItem(id: .new, title: "New Profile", systemImage: "plus",
            isEnabled: draftReason == nil, disabledReason: draftReason)
        let duplicate = ProfileActionItem(id: .duplicate,
            title: isDefaultProfile ? "Duplicate Default to Edit" : "Duplicate Profile",
            systemImage: "plus.square.on.square",
            isEnabled: draftReason == nil, disabledReason: draftReason)
        let deleteReason = editReason ?? draftReason

        sections = [
            isDefaultProfile ? [duplicate, create] : [create, duplicate],
            [
                ProfileActionItem(id: .rename, title: "Rename Profile", systemImage: "pencil",
                    isEnabled: editReason == nil, disabledReason: editReason),
                ProfileActionItem(id: .revertToSaved, title: "Revert to Saved",
                    systemImage: "arrow.uturn.backward",
                    isEnabled: canRevertToSaved,
                    disabledReason: canRevertToSaved ? nil : "There are no unsaved changes to revert"),
                ProfileActionItem(id: .restoreDefaults, title: "Restore Defaults",
                    systemImage: "arrow.counterclockwise",
                    isEnabled: editReason == nil, disabledReason: editReason)
            ],
            [
                ProfileActionItem(id: .delete, title: "Delete Profile", systemImage: "trash",
                    isEnabled: deleteReason == nil, isDestructive: true, disabledReason: deleteReason)
            ]
        ]
    }

    @MainActor
    init(model: PaddrMenuModel) {
        self.init(
            isDefaultProfile: model.activeProfileID == .default,
            hasUnsavedChanges: model.hasUnsavedChanges,
            canEditActiveProfile: model.canEditActiveProfile,
            canRevertToSaved: model.canRevertToSaved
        )
    }
}

/// Dialog state for profile commands. The toolbar controls and the workspace
/// share one instance, and the dialogs attach to the window content, so an
/// alert never hangs off a toolbar item.
@MainActor
@Observable
final class ProfileCommands {
    var pendingProfileAction: PendingProfileAction?
    var confirmationSelectionID: ConfigurationProfileID?
    var showsDiscardConfirmation = false
    var showsRestoreConfirmation = false
    var showsRevertConfirmation = false
    var nameDraft = ""

    func select(_ id: ConfigurationProfileID, in model: PaddrMenuModel) {
        switch model.requestProfileSelection(id: id, source: .configurationWindow) {
        case .confirmationRequired:
            confirmationSelectionID = id
            showsDiscardConfirmation = true
        case .accepted, .blockedByUnsavedChanges, .cancelled, .operationInProgress,
             .profileNotFound, .storageUnavailable, .unchanged:
            break
        }
    }

    func perform(_ action: ProfileAction, in model: PaddrMenuModel) {
        switch action {
        case .new:
            nameDraft = String(localized: "New Profile")
            pendingProfileAction = .create(suggestedName: nameDraft)
        case .duplicate:
            _ = model.duplicateActiveProfile()
        case .rename:
            nameDraft = model.activeProfile.name
            pendingProfileAction = .rename(id: model.activeProfileID, name: model.activeProfile.name)
        case .revertToSaved:
            // Reverting only ever discards work, so it always asks first.
            if model.canRevertToSaved { showsRevertConfirmation = true }
        case .restoreDefaults:
            if model.hasUnsavedChanges {
                showsRestoreConfirmation = true
            } else {
                model.restoreDefaults()
            }
        case .delete:
            pendingProfileAction = .delete(id: model.activeProfileID, name: model.activeProfile.name)
        }
    }

    func isPresented(_ kind: PendingProfileAction.Kind) -> Binding<Bool> {
        Binding(
            get: { self.pendingProfileAction?.kind == kind },
            set: { isPresented in
                if !isPresented, self.pendingProfileAction?.kind == kind {
                    self.pendingProfileAction = nil
                }
            }
        )
    }
}

struct PendingProfileAction: Equatable {
    enum Kind: Equatable {
        case create
        case rename
        case delete
    }

    let kind: Kind
    let profileID: ConfigurationProfileID?
    let profileName: String

    static func create(suggestedName: String) -> Self {
        Self(kind: .create, profileID: nil, profileName: suggestedName)
    }

    static func rename(id: ConfigurationProfileID, name: String) -> Self {
        Self(kind: .rename, profileID: id, profileName: name)
    }

    static func delete(id: ConfigurationProfileID, name: String) -> Self {
        Self(kind: .delete, profileID: id, profileName: name)
    }
}

struct ProfilePickerPresentation: Equatable {
    struct Option: Identifiable, Equatable {
        let id: ConfigurationProfileID
        let label: String
    }

    let options: [Option]
    let accessibilityValue: String

    @MainActor
    init(model: PaddrMenuModel) {
        self.init(
            profiles: model.profiles,
            activeProfileName: model.activeProfile.name,
            selection: model.profileSelectionPresentation
        )
    }

    init(
        profiles: [ConfigurationProfile],
        activeProfileName: String,
        selection: ProfileSelectionPresentation
    ) {
        switch selection {
        case .active:
            options = profiles.map { Option(id: $0.id, label: $0.name) }
            accessibilityValue = activeProfileName

        case let .switching(to: pendingID, named: pendingName):
            let pendingLabel = String(
                localized: "Switching to \(pendingName)…",
                comment: "Profile selector value while the selected profile is being saved"
            )
            var presentedOptions = profiles.map { profile in
                Option(
                    id: profile.id,
                    label: profile.id == pendingID ? pendingLabel : profile.name
                )
            }
            if !presentedOptions.contains(where: { $0.id == pendingID }) {
                presentedOptions.append(Option(id: pendingID, label: pendingLabel))
            }
            options = presentedOptions
            accessibilityValue = String(
                localized: "Switching to \(pendingName)",
                comment: "Profile selector accessibility value while the selected profile is being saved"
            )
        }
    }
}

/// The profile alerts and confirmations, attached once to the window content.
struct ProfileDialogs: ViewModifier {
    let model: PaddrMenuModel
    @Bindable var commands: ProfileCommands

    func body(content: Content) -> some View {
        content
            .alert("Restore defaults?", isPresented: $commands.showsRestoreConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Restore Defaults", role: .destructive) {
                    model.restoreDefaults(discardChanges: true)
                }
            } message: {
                Text("This replaces your unsaved draft with defaults. Save & Apply is still required to update the profile.")
            }
            .alert("Revert to saved?", isPresented: $commands.showsRevertConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Revert to Saved", role: .destructive) {
                    model.revertToSaved()
                }
            } message: {
                Text("This discards your unsaved changes and shows the profile as it was last saved. Mapped output is not affected.")
            }
            .alert("Discard unsaved changes?", isPresented: $commands.showsDiscardConfirmation) {
                Button("Cancel", role: .cancel) { resolveSelection(discardChanges: false) }
                Button("Discard Changes", role: .destructive) { resolveSelection(discardChanges: true) }
            } message: {
                Text("Switching profiles replaces the current draft. Unsaved changes will not be copied.")
            }
            .alert("Create Profile", isPresented: commands.isPresented(.create)) {
                TextField("Profile name", text: $commands.nameDraft)
                Button("Cancel", role: .cancel) { commands.pendingProfileAction = nil }
                Button("Create") {
                    guard commands.pendingProfileAction?.kind == .create else { return }
                    _ = model.createProfile(named: commands.nameDraft)
                    commands.pendingProfileAction = nil
                }
            } message: {
                Text("Profile names must be nonempty and unique, ignoring case.")
            }
            .alert("Rename Profile", isPresented: commands.isPresented(.rename)) {
                TextField("Profile name", text: $commands.nameDraft)
                Button("Cancel", role: .cancel) { commands.pendingProfileAction = nil }
                Button("Rename") {
                    guard commands.pendingProfileAction?.kind == .rename,
                          let id = commands.pendingProfileAction?.profileID else { return }
                    _ = model.renameProfile(id: id, to: commands.nameDraft)
                    commands.pendingProfileAction = nil
                }
            } message: {
                Text("Profile names must be nonempty and unique, ignoring case.")
            }
            .confirmationDialog(
                "Delete \(commands.pendingProfileAction?.profileName ?? "")?",
                isPresented: commands.isPresented(.delete),
                titleVisibility: .visible
            ) {
                Button("Delete Profile", role: .destructive) {
                    guard commands.pendingProfileAction?.kind == .delete,
                          let id = commands.pendingProfileAction?.profileID else { return }
                    _ = model.deleteProfile(id: id, confirmed: true)
                    commands.pendingProfileAction = nil
                }
                Button("Cancel", role: .cancel) { commands.pendingProfileAction = nil }
            } message: {
                Text("Deleting the active profile activates Default first. This cannot be undone.")
            }
    }

    private func resolveSelection(discardChanges: Bool) {
        if let id = commands.confirmationSelectionID {
            _ = model.resolveProfileSelection(id: id, discardChanges: discardChanges)
        }
        commands.confirmationSelectionID = nil
    }
}

extension View {
    func profileDialogs(model: PaddrMenuModel, commands: ProfileCommands) -> some View {
        modifier(ProfileDialogs(model: model, commands: commands))
    }
}
