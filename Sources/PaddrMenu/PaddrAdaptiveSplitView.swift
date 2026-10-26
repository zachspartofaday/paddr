import SwiftUI

extension EnvironmentValues {
    /// Coarsened at the adaptive breakpoint so a card can fill the finite
    /// tallest-column proposal without reacting to every resize point.
    @Entry var paddrFillsEqualHeightColumn = false
}

/// Changes layout without creating parallel copies of its stateful children.
/// `AnyLayout` keeps one mounted subtree while moving the same children between
/// horizontal and vertical arrangements.
struct PaddrAdaptiveSplitView<Leading: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let breakpoint: CGFloat
    let leadingWidth: CGFloat?
    let showsDivider: Bool
    let equalizesColumnHeights: Bool
    let columnSpacing: CGFloat
    let alignsPadInspector: Bool
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    @State private var availableWidth = PaddrStyle.Metrics.defaultContentWidth

    init(
        breakpoint: CGFloat,
        leadingWidth: CGFloat,
        showsDivider: Bool = true,
        alignsPadInspector: Bool = false,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.breakpoint = breakpoint
        self.leadingWidth = leadingWidth
        self.showsDivider = showsDivider
        self.alignsPadInspector = alignsPadInspector
        equalizesColumnHeights = false
        columnSpacing = PaddrStyle.previewInspectorSpacing
        self.leading = leading
        self.trailing = trailing
    }

    /// Creates a dividerless, equal-width split whose columns share the
    /// tallest intrinsic height. Keeping this as a separate initializer makes
    /// unsupported fixed-leading or divider combinations unrepresentable.
    init(
        equalHeightColumnsBreakpoint breakpoint: CGFloat,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.breakpoint = breakpoint
        leadingWidth = nil
        showsDivider = false
        alignsPadInspector = false
        equalizesColumnHeights = true
        columnSpacing = PaddrStyle.cardSpacing
        self.leading = leading
        self.trailing = trailing
    }

    /// Equal widths with independent natural heights, for the mapping workspace.
    init(
        columnsBreakpoint breakpoint: CGFloat,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.breakpoint = breakpoint
        leadingWidth = nil
        showsDivider = false
        alignsPadInspector = false
        equalizesColumnHeights = false
        columnSpacing = PaddrStyle.Spacing.s5
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        let usesColumns = availableWidth >= breakpoint && !dynamicTypeSize.isAccessibilitySize
        let usesEqualHeightColumns = usesColumns && equalizesColumnHeights
        let resolvedSpacing = alignsPadInspector ? PaddrPadColumns.spacing(in: availableWidth) : columnSpacing
        let resolvedLeadingWidth = alignsPadInspector
            ? PaddrPadColumns.previewWidth(in: availableWidth) : leadingWidth
        let layout = usesEqualHeightColumns
            ? AnyLayout(PaddrEqualHeightColumnsLayout(spacing: columnSpacing))
            : usesColumns
                ? AnyLayout(HStackLayout(alignment: .top, spacing: resolvedSpacing))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: PaddrStyle.Spacing.s4))

        layout {
            leading()
                .frame(width: usesColumns ? resolvedLeadingWidth : nil, alignment: .topLeading)
                .frame(
                    minWidth: usesColumns && leadingWidth != nil ? nil : 0,
                    maxWidth: usesColumns && leadingWidth != nil ? nil : .infinity,
                    alignment: .topLeading
                )
                .frame(
                    maxHeight: usesEqualHeightColumns ? .infinity : nil,
                    alignment: .topLeading
                )
                .environment(\.paddrFillsEqualHeightColumn, usesEqualHeightColumns)
            if showsDivider {
                Divider()
            }
            trailing()
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                .frame(
                    maxHeight: usesEqualHeightColumns ? .infinity : nil,
                    alignment: .topLeading
                )
                .environment(\.paddrFillsEqualHeightColumn, usesEqualHeightColumns)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
            guard width > 0 else { return }
            availableWidth = width
        }
    }
}

/// Shared column geometry for the mode header and every preview/inspector pair.
/// Surplus width belongs to the map column, leaving the trailing control column
/// aligned to the fixed 272-point mode control. The map itself stays 190 points.
enum PaddrPadColumns {
    static let minimumInlineWidth = PaddrStyle.Metrics.zoneMapWidth
        + PaddrStyle.behaviorPickerWidth + PaddrStyle.Spacing.s2

    static func spacing(in availableWidth: CGFloat) -> CGFloat {
        guard availableWidth >= minimumInlineWidth else { return PaddrStyle.previewInspectorSpacing }
        return min(PaddrStyle.previewInspectorSpacing,
            availableWidth - PaddrStyle.Metrics.zoneMapWidth - PaddrStyle.behaviorPickerWidth)
    }
    static func previewWidth(in availableWidth: CGFloat) -> CGFloat {
        max(PaddrStyle.Metrics.zoneMapWidth,
            availableWidth - PaddrStyle.behaviorPickerWidth - spacing(in: availableWidth))
    }
    static func inspectorLeading(in availableWidth: CGFloat) -> CGFloat {
        previewWidth(in: availableWidth) + spacing(in: availableWidth)
    }
}
