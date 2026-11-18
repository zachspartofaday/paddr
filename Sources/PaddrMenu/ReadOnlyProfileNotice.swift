import PaddrAppSupport
import SwiftUI

/// Says why every editing control is disabled while Default is active, next to
/// the one command that makes them editable.
struct ReadOnlyProfileNotice: View {
    let model: PaddrMenuModel
    let commands: ProfileCommands
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: PaddrStyle.Spacing.s2))
            : AnyLayout(HStackLayout(alignment: .center, spacing: PaddrStyle.Spacing.s3))

        layout {
            Label {
                Text("Default is read-only. Duplicate it to make changes.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lock")
                    .foregroundStyle(PaddrStyle.textSecondary)
                    .accessibilityHidden(true)
            }
            .paddrTypography(.rowLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .paddrAccessibilityID("profile", "read-only-notice")

            Button("Duplicate to Edit") { commands.perform(.duplicate, in: model) }
                .paddrActionButton(.primary)
                .fixedSize()
                .disabled(disabledReason != nil)
                .help(disabledReason.map { Text($0) }
                    ?? Text("Duplicate Default to create an editable profile"))
                .paddrAccessibilityID("profile", "duplicate-to-edit")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The same gate as the Duplicate command in the profile menu.
    var disabledReason: LocalizedStringResource? {
        guard model.canManageProfiles else { return "Wait for the profile operation to finish" }
        return ProfileActionsPresentation(model: model).item(.duplicate)?.disabledReason
    }
}
