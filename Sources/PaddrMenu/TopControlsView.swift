import PaddrAppSupport
import SwiftUI

/// Persistent profile and commit controls; only the mapping workspace scrolls.
struct TopControlsView: View {
    private static let reflowBreakpoint: CGFloat = 680

    @Bindable var model: PaddrMenuModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        let usesInlineLayout = availableWidth > Self.reflowBreakpoint && !dynamicTypeSize.isAccessibilitySize
        let controlsLayout = usesInlineLayout
            ? AnyLayout(HStackLayout(alignment: .center, spacing: PaddrStyle.Spacing.s3))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: PaddrStyle.Spacing.s2))

        controlsLayout {
            ProfileControlsView(model: model)
            HStack(spacing: PaddrStyle.Spacing.s3) {
                saveState
                if !usesInlineLayout { Spacer(minLength: PaddrStyle.Spacing.s3) }
                Button("Save & Apply", action: model.saveAndApply)
                    .paddrActionButton(.primary)
                    .disabled(!model.canSaveAndApply)
                    .keyboardShortcut("s", modifiers: .command)
                    .paddrAccessibilityID("profile", "save-apply")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
            guard width > 0 else { return }
            availableWidth = width
        }
    }

    private var saveState: some View {
        Text(model.hasUnsavedChanges ? "Unsaved changes" : "Saved")
            .paddrTypography(.caption)
            .foregroundStyle(model.hasUnsavedChanges ? PaddrStyle.warningText : PaddrStyle.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(model.hasUnsavedChanges ? Text("Unsaved changes") : Text("Configuration saved"))
    }
}
