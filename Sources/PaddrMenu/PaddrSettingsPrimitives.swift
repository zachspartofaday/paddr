import AppKit
import SwiftUI

extension EnvironmentValues {
    /// Compact inspectors place each label directly above its native control.
    @Entry var paddrStacksSettingLabels = false
}

struct PaddrSectionContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
    }

}

/// A natural-height, noninteractive heading for regions inside a card. Keeping headings
/// out of the control-row height family makes the declared surface inset visually exact.
struct PaddrSectionHeader: View {
    let title: LocalizedStringResource

    init(_ title: LocalizedStringResource) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .paddrTypography(.sectionTitle)
            .accessibilityAddTraits(.isHeader)
    }
}

struct PaddrInsetDivider: View {
    enum Axis {
        case horizontal
        case vertical
    }

    var axis: Axis = .horizontal

    var body: some View {
        PaddrAppearanceReader { appearance in
            Rectangle()
                .fill(appearance.surfaceStroke)
                .frame(
                    maxWidth: axis == .horizontal ? .infinity : 1,
                    maxHeight: axis == .vertical ? .infinity : 1
                )
                .padding(
                    axis == .horizontal ? .horizontal : .vertical,
                    axis == .horizontal ? PaddrStyle.Spacing.s2 : PaddrStyle.Spacing.s3
                )
        }
    }
}

/// Native settings rows use labels above controls in compact map inspectors.
/// Wider horizontal forms retain a label column and trailing control alignment.
struct PaddrSettingsRow<Control: View>: View {
    @Environment(\.paddrStacksSettingLabels) private var stacksLabels
    let title: LocalizedStringResource
    let systemImage: String
    /// Picker rows and slider rows need different label columns; see `PaddrStyle.Width`.
    var labelWidth: CGFloat? = PaddrStyle.Width.labelColumn
    @ViewBuilder let control: () -> Control

    var body: some View {
        let layout = stacksLabels
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: PaddrStyle.Spacing.s1))
            : AnyLayout(HStackLayout(spacing: PaddrStyle.Spacing.s3))
        layout {
            label
                .frame(width: stacksLabels ? nil : labelWidth, alignment: .leading)
                .layoutPriority(stacksLabels || labelWidth == nil ? 1 : 0)
            control()
                .frame(maxWidth: .infinity, alignment: stacksLabels ? .leading : .trailing)
        }
        .frame(maxWidth: .infinity, minHeight: PaddrStyle.Metrics.row, alignment: .leading)
    }

    private var label: some View {
        Text(title)
            .paddrTypography(.rowLabel)
            .accessibilityHidden(true)
    }
}

/// Lays out settings rows on the shared row spacing, and carries the inset divider that
/// separates one declared group from the group above it, so call sites stop hand-placing
/// dividers and one-off top padding.
struct PaddrSettingsGroup<Content: View>: View {
    var showsLeadingDivider: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            if showsLeadingDivider {
                PaddrInsetDivider()
            }
            content()
        }
    }
}
