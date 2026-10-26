import SwiftUI

struct PermissionTile: View {
    let title: LocalizedStringResource
    let detail: LocalizedStringResource
    let isGranted: Bool
    var identifier: String = "permission"
    var identifierPrefix: String = "permissions"
    let requestAccessibilityLabel: LocalizedStringResource
    let settingsAccessibilityLabel: LocalizedStringResource
    let requestAction: () -> Void
    let settingsAction: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        let usesColumns = availableWidth >= 500 && !dynamicTypeSize.isAccessibilitySize
        let layout = usesColumns
            ? AnyLayout(HStackLayout(alignment: .center, spacing: PaddrStyle.Spacing.s3))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: PaddrStyle.Spacing.s2))

        layout {
            VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s1) {
                Label(title, systemImage: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .paddrTypography(.sectionLabel)
                Text(isGranted ? "Ready" : "Needed")
                    .paddrTypography(.caption)
                    .foregroundStyle(isGranted ? PaddrStyle.activeText : PaddrStyle.warningText)
                Text(detail)
                    .paddrTypography(.caption)
                    .foregroundStyle(PaddrStyle.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: PaddrStyle.Spacing.s2) {
                Button("Request", action: requestAction)
                    .paddrActionButton(.secondary)
                    .disabled(isGranted)
                    .accessibilityLabel(requestAccessibilityLabel)
                    .paddrAccessibilityID(identifierPrefix, identifier, "request")
                Button("Open Settings", action: settingsAction)
                    .paddrActionButton(.secondary)
                    .accessibilityLabel(settingsAccessibilityLabel)
                    .paddrAccessibilityID(identifierPrefix, identifier, "settings")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityValue(isGranted ? Text("Ready") : Text("Needed"))
        .paddrAccessibilityID(identifierPrefix, identifier)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
            guard width > 0 else { return }
            availableWidth = width
        }
    }
}
