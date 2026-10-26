import PaddrAppSupport
import SwiftUI

/// One permission flow is shared by the configuration window and the guide.
struct PermissionSetupContent: View {
    @Bindable var model: PaddrMenuModel
    var identifierPrefix: String = "permissions"

    var body: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s5) {
            PermissionTile(
                title: "Input Monitoring",
                detail: "Receives Steam Controller 2 reports from the puck.",
                isGranted: model.inputMonitoringGranted,
                identifier: "input-monitoring",
                identifierPrefix: identifierPrefix,
                requestAccessibilityLabel: "Request Input Monitoring",
                settingsAccessibilityLabel: "Open Input Monitoring Settings",
                requestAction: model.requestInputMonitoring,
                settingsAction: model.openInputMonitoringSettings
            )
            PermissionTile(
                title: "Accessibility",
                detail: "Sends mapped mouse, scroll, and keyboard input.",
                isGranted: model.accessibilityTrusted,
                identifier: "accessibility",
                identifierPrefix: identifierPrefix,
                requestAccessibilityLabel: "Request Accessibility",
                settingsAccessibilityLabel: "Open Accessibility Settings",
                requestAction: model.requestAccessibility,
                settingsAction: model.openAccessibilitySettings
            )
        }
    }
}

struct PermissionSetupView: View {
    @Bindable var model: PaddrMenuModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s4) {
            Text("Allow access")
                .paddrTypography(.pageTitle)
                .accessibilityAddTraits(.isHeader)
            Text("Allow Paddr to read your controller and send your mapped actions. You can edit profiles before granting access.")
                .foregroundStyle(PaddrStyle.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                PermissionSetupContent(model: model)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, PaddrStyle.Spacing.s2)
            }
            .frame(maxHeight: 360)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .paddrActionButton(.primary)
                    .paddrAccessibilityID("permissions", "done")
            }
        }
        .padding(PaddrStyle.Inset.window)
        .frame(width: 560)
        .foregroundStyle(PaddrStyle.textPrimary)
        .background(PaddrStyle.workspace)
    }
}
