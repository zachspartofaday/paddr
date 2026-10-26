import PaddrCore
import SwiftUI

struct RearButtonConfigurationView: View {
    @Binding var configuration: RearButtonConfiguration
    let isEditable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            Text("Rear buttons")
                .paddrTypography(.sectionLabel)
                .foregroundStyle(PaddrStyle.textPrimary)
                .accessibilityAddTraits(.isHeader)
            PaddrAdaptiveSplitView(
                columnsBreakpoint: PaddrStyle.Metrics.padEditorColumnsBreakpoint,
                leading: {
                    PaddrWrappingHStack(horizontalSpacing: PaddrStyle.Spacing.s4, verticalSpacing: PaddrStyle.Spacing.s2) {
                        rearRow("L4", title: "Left rear button L4 action", selection: $configuration.l4)
                        rearRow("L5", title: "Left rear button L5 action", selection: $configuration.l5)
                    }
                },
                trailing: {
                    PaddrWrappingHStack(horizontalSpacing: PaddrStyle.Spacing.s4, verticalSpacing: PaddrStyle.Spacing.s2) {
                        rearRow("R4", title: "Right rear button R4 action", selection: $configuration.r4)
                        rearRow("R5", title: "Right rear button R5 action", selection: $configuration.r5)
                    }
                }
            )
            .disabled(!isEditable)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paddrAccessibilityID("rear-buttons")
    }

    private func rearRow(
        _ code: LocalizedStringResource,
        title: LocalizedStringResource,
        selection: Binding<String?>
    ) -> some View {
        HStack(spacing: PaddrStyle.Spacing.s2) {
            Text(code)
                .paddrTypography(.rowLabel)
            OptionalOutputBindingPicker(selection: selection, title: title)
                .help("Hold this rear button to hold its assigned action. None sends no input.")
        }
    }
}
