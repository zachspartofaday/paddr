import PaddrCore
import SwiftUI

struct RearButtonConfigurationView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var configuration: RearButtonConfiguration
    let isEditable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            Text("Rear buttons")
                .paddrTypography(.sectionLabel)
                .foregroundStyle(PaddrStyle.textPrimary)
                .accessibilityAddTraits(.isHeader)
            PaddrRearSelectorsLayout(allowsInlineInspectors: !dynamicTypeSize.isAccessibilitySize) {
                rearRow("L4", title: "Left rear button L4 action", selection: $configuration.l4)
                rearRow("L5", title: "Left rear button L5 action", selection: $configuration.l5)
                rearRow("R4", title: "Right rear button R4 action", selection: $configuration.r4)
                rearRow("R5", title: "Right rear button R5 action", selection: $configuration.r5)
            }
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
            OptionalOutputBindingPicker(selection: selection, title: title, width: PaddrStyle.Width.rearControl)
                .help("Hold this rear button to hold its assigned action. None sends no input.")
        }
    }
}

/// Places the existing code/menu pairs without rebuilding their native controls.
/// Coordinates are logical; SwiftUI mirrors the complete arrangement once in RTL.
private struct PaddrRearSelectorsLayout: Layout {
    let allowsInlineInspectors: Bool
    private let wrapping = PaddrWrappingHStack(
        horizontalSpacing: PaddrStyle.Spacing.s4,
        verticalSpacing: PaddrStyle.Spacing.s2,
        maximumItemsPerRow: 2
    )

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // An unspecified proposal asks for the ideal size, not the fallback's
        // minimum row count. Match the preferred workspace so fittingSize and
        // the mounted default document agree about the one-row height.
        let width = proposal.width ?? (PaddrStyle.Metrics.defaultWindowSize.width - 2 * PaddrStyle.Inset.chrome)
        if let row = inlineRow(width: width, subviews: subviews) {
            return CGSize(width: width, height: row.sizes.map(\.height).max() ?? 0)
        }
        return wrapping.sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let row = inlineRow(width: bounds.width, subviews: subviews) else {
            wrapping.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &cache)
            return
        }
        for index in subviews.indices {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + row.origins[index], y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(row.sizes[index])
            )
        }
    }

    private func inlineRow(width: CGFloat, subviews: Subviews) -> (sizes: [CGSize], origins: [CGFloat])? {
        guard allowsInlineInspectors, width.isFinite, subviews.count == 4,
              let edges = PaddrPadColumns.workspaceInspectorTrailingEdges(in: width) else { return nil }
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        // L5/R5 anchor two intervals apart, fixing the stride for all four menus.
        let stride = (edges.right - edges.left) / 2
        let ends = [edges.left - stride, edges.left, edges.right - stride, edges.right]
        let origins = zip(ends, sizes).map { $0 - $1.width }
        guard origins[0] >= 0, ends[3] <= width,
              (1..<4).allSatisfy({ origins[$0] >= ends[$0 - 1] + PaddrStyle.Spacing.s4 }) else { return nil }
        return (sizes, origins)
    }
}
