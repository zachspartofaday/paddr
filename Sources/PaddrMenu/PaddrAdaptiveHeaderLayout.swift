import SwiftUI

/// Keeps a card title and its trailing control on one row when their intrinsic
/// widths fit, then moves that same control below the title at constrained widths.
/// A custom layout avoids mounting parallel copies of stateful native controls.
/// Placement uses logical coordinates; SwiftUI mirrors them once for RTL.
struct PaddrAdaptiveHeaderLayout: Layout {
    let spacing: CGFloat
    var alignsPadInspector = false
    var forceStacked = false

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let geometry = geometry(
            availableWidth: finiteWidth(proposal.width),
            subviews: subviews
        ) else {
            return .zero
        }

        return CGSize(
            width: finiteWidth(proposal.width) ?? geometry.contentWidth,
            height: geometry.height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let geometry = geometry(
            availableWidth: bounds.width,
            subviews: subviews
        ) else {
            return
        }

        let titleX = bounds.minX
        if geometry.usesInlineLayout {
            subviews[0].place(
                at: CGPoint(
                    x: titleX,
                    y: bounds.midY - (geometry.titleSize.height / 2)
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(geometry.titleSize)
            )
            subviews[1].place(
                at: CGPoint(
                    x: bounds.minX + geometry.controlLeading,
                    y: bounds.midY - (geometry.controlSize.height / 2)
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(geometry.controlSize)
            )
        } else {
            subviews[0].place(
                at: CGPoint(x: titleX, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(geometry.titleSize)
            )
            subviews[1].place(
                at: CGPoint(
                    x: bounds.minX,
                    y: bounds.minY + geometry.titleSize.height + spacing
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(geometry.controlSize)
            )
        }
    }

    private func geometry(
        availableWidth: CGFloat?,
        subviews: Subviews
    ) -> HeaderGeometry? {
        guard subviews.count == 2 else { return nil }

        let naturalTitleSize = subviews[0].sizeThatFits(.unspecified)
        let controlSize = subviews[1].sizeThatFits(.unspecified)
        let inlineWidth = naturalTitleSize.width + spacing + controlSize.width
        let idealInlineWidth = alignsPadInspector
            ? max(inlineWidth, PaddrPadColumns.minimumInlineWidth) : inlineWidth
        let availableWidth = availableWidth ?? idealInlineWidth
        let controlLeading = alignsPadInspector
            ? PaddrPadColumns.inspectorLeading(in: availableWidth)
            : availableWidth - controlSize.width
        let usesInlineLayout = !forceStacked && availableWidth >= inlineWidth
            && controlLeading >= naturalTitleSize.width + spacing
            && controlLeading + controlSize.width <= availableWidth
        let titleSize = usesInlineLayout
            ? naturalTitleSize
            : subviews[0].sizeThatFits(
                ProposedViewSize(width: availableWidth, height: nil)
            )

        return HeaderGeometry(
            controlLeading: controlLeading,
            titleSize: titleSize,
            controlSize: controlSize,
            usesInlineLayout: usesInlineLayout,
            contentWidth: usesInlineLayout
                ? idealInlineWidth
                : max(titleSize.width, controlSize.width),
            height: usesInlineLayout
                ? max(titleSize.height, controlSize.height)
                : titleSize.height + spacing + controlSize.height
        )
    }

    private func finiteWidth(_ width: CGFloat?) -> CGFloat? {
        width.flatMap { $0.isFinite ? max(0, $0) : nil }
    }
}

private struct HeaderGeometry {
    let controlLeading: CGFloat
    let titleSize: CGSize
    let controlSize: CGSize
    let usesInlineLayout: Bool
    let contentWidth: CGFloat
    let height: CGFloat
}
