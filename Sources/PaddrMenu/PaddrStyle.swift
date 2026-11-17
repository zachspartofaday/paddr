import AppKit
import SwiftUI

/// The only vocabulary `PaddrMenu` text uses for a font. Every role carries its own
/// weight, so no call site follows `paddrTypography(_:)` with an ad-hoc `bold()`.
enum PaddrTextRole {
    /// Guide header.
    case pageTitle
    /// Pad-card and guide-page titles.
    case cardTitle
    /// Titles for preview and settings regions within a card.
    case sectionTitle
    /// Column and band headers.
    case sectionLabel
    /// Settings-row labels.
    case rowLabel
    /// Status values and numeric readouts.
    case value
    /// Detail and secondary text.
    case caption
    /// Key plates and the neutral-zone mark drawn on a pad map.
    case bindingPlate
    /// The mode glyph drawn at the centre of a pad preview.
    case padGlyph

    var font: Font {
        switch self {
        case .pageTitle: .title.bold()
        case .cardTitle: .title2.weight(.semibold)
        case .sectionTitle: .title3.weight(.semibold)
        case .sectionLabel: .headline.weight(.semibold)
        case .rowLabel: .body
        case .value: .body.monospacedDigit()
        case .caption: .callout
        case .bindingPlate: .caption.bold()
        case .padGlyph: .title3.weight(.medium)
        }
    }
}

/// Emphasis of an action button. A band carries at most one `primary`.
enum PaddrButtonRole {
    case primary
    case secondary
    /// Icon-only; the role applies `labelStyle(.iconOnly)` so call sites do not repeat it.
    case icon
}

enum PaddrStyle {
    /// The one spacing scale. `s1` separates an icon from its label, `s2` two controls,
    /// `s3` two rows, `s4` two bands or a panel edge, `s5` the guide's bands.
    enum Spacing {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
        static let s5: CGFloat = 24
    }

    /// Semantic insets establish one surface hierarchy across the app: the workspace
    /// sits one window margin in from the window edge, panels share one interior
    /// margin, and compact controls use the next smaller step.
    enum Inset {
        static let window = Spacing.s5
        static let card = Spacing.s4
        static let section = Spacing.s4
        static let control = Spacing.s3
    }

    /// The bar that floats over the bottom of the workspace. Its margin and
    /// interior inset add up to the window margin, so what the bar holds lines up
    /// with the workspace content above it.
    enum Bar {
        static let margin = Spacing.s3
        static let inset = Inset.window - margin
        static let verticalInset = Spacing.s3
    }

    /// Visible control geometry, separate from layout row metrics.
    enum Control {
        static let height: CGFloat = 32
        static let radius: CGFloat = 7
        static let sideInset: CGFloat = 12
        static let focusWidth: CGFloat = 2
        static let outlineWidth: CGFloat = 2
        static let segmentInset: CGFloat = 4
        static let segmentGap: CGFloat = 2
        static let segmentRadius: CGFloat = radius - segmentInset
        static let bindingPlateHeight: CGFloat = 24
        static let bindingPlateRadius: CGFloat = 5
        enum TuningSwitch {
            static let track = CGSize(width: 44, height: 24)
            static let thumb = CGSize(width: 18, height: 18)
            static let thumbRadius: CGFloat = 4
            static let inset: CGFloat = 3
            static let travel: CGFloat = 20
        }
    }

    /// Heights and fixed surface sizes. `row` is the single interactive-row family
    /// (settings row and permission row); headings keep their natural height.
    /// Visible control geometry belongs to `Control`.
    enum Metrics {
        static let controlHeight: CGFloat = 32
        static let row = controlHeight
        /// Icon column in Connection details, so the names beside it share an edge.
        static let statusIconColumn: CGFloat = 20

        static let outerSpacing = Inset.window
        /// Preferred width and temporary opening height before content is measured.
        /// The configuration window then fits its measured content to the screen.
        static let defaultWindowSize = NSSize(
            width: (2 * (zoneMapWidth + PaddrStyle.previewInspectorSpacing + Width.control))
                + Spacing.s5 + (2 * Inset.window), height: 640)
        static let defaultContentWidth = defaultWindowSize.width - (2 * outerSpacing)
        /// Below this content width, two complete pad editors no longer have
        /// enough room for their native mode controls and stack vertically.
        static let padEditorColumnsBreakpoint = (2 * PaddrStyle.minimumPadColumnWidth) + Spacing.s5
        /// Below this width, the output switch gets its own line.
        static let statusBarInlineBreakpoint: CGFloat = 760
        /// Compact layout evidence budget; managed windows can be shorter when content fits.
        static let minimumWindowSize = NSSize(width: 680, height: 600)
        /// Historical permission-column budget retained for compatible layout fixtures.
        static let permissionColumnsBreakpoint: CGFloat = 960

        static let zoneMapWidth: CGFloat = 190
        static let zoneMapHeight: CGFloat = 182
    }

    enum Depth {
        static let padRecessOpacity: Double = 0.18
        static let padRecessRadius: CGFloat = 3
        static let padRecessOffset: CGFloat = 2
    }

    enum Radius {
        /// Setup panel, banner or floating bar.
        static let card: CGFloat = 12
        /// Inset controls and status containers. Binding plates have their own role.
        static let control: CGFloat = 7
        /// Shared visual shell; runtime region geometry is unchanged.
        static let pad: CGFloat = 14
    }

    /// Width budgets for native labels and controls. Pad modes, menus and tuning
    /// readouts share one moderate-width inspector column.
    enum Width {
        /// Numeric value column, monospaced and trailing-aligned.
        static let readout: CGFloat = 40
        /// Gyro rates include a unit (pt/° or °/s) and need a wider value column.
        static let gyroReadout: CGFloat = 76
        static let toggle: CGFloat = 52
        /// Modes, selectors and the complete slider/readout rows.
        static let control: CGFloat = 240
        /// Four rear label/menu pairs fit the compact workspace without widening
        /// its pad columns; longer values grow vertically and whole pairs wrap.
        static let rearControl: CGFloat = 180
        /// The area-layout picker, whose longest value is "Four-way radial".
        static let controlMedium: CGFloat = control
        /// Label column for rows whose control is a fixed-width picker.
        static let labelColumn: CGFloat = 108
        /// Label column for slider rows. It is wide enough for "Pointer acceleration"
        /// while preserving a usable native slider at the dual-column breakpoint.
        static let labelColumnWide: CGFloat = 136
    }

    /// Paddr's adaptive palette. AppKit resolves these colors with the hosting window's
    /// appearance; controls reuse these colors without introducing another palette.
    static func adaptiveColor(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: adaptiveNSColor(light: light, dark: dark))
    }

    /// The AppKit form of a token. It resolves with the appearance of whatever draws it,
    /// so the menu-bar item follows the menu bar and not the configuration window.
    static func adaptiveNSColor(light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((value >> 16) & 0xff) / 255,
                green: CGFloat((value >> 8) & 0xff) / 255,
                blue: CGFloat(value & 0xff) / 255,
                alpha: 1
            )
        }
    }

    static let canvas = adaptiveColor(light: 0xF3F5F7, dark: 0x20262D)
    static let workspace = adaptiveColor(light: 0xFFFFFF, dark: 0x2B333C)
    static let textPrimary = adaptiveColor(light: 0x1C2630, dark: 0xF0F4F8)
    static let textSecondary = adaptiveColor(light: 0x52616E, dark: 0xBAC6D2)
    static let textTertiary = textSecondary
    static let boundary = adaptiveColor(light: 0xCBD3DB, dark: 0x536372)
    static let action = adaptiveColor(light: 0x2859CF, dark: 0x78C7BD)
    static let successGreenNSColor = adaptiveNSColor(light: 0x206644, dark: 0x70D4A7)
    static let cautionAmberNSColor = adaptiveNSColor(light: 0x855000, dark: 0xFFD080)
    static let successGreen = Color(nsColor: successGreenNSColor)
    static let cautionAmber = Color(nsColor: cautionAmberNSColor)
    static let errorText = adaptiveColor(light: 0xB3261E, dark: 0xFFAAA3)

    // Role names for the status and accent text that views read.
    static let active = successGreen
    static let activeText = successGreen
    static let accentText = action
    static let warningText = cautionAmber
    static let successText = successGreen

    /// The resting surface of menus, mode tracks, switch tracks and secondary buttons.
    /// It is opaque, so a control looks the same with Reduce Transparency or
    /// Increase Contrast as it does without them.
    static let controlFill = adaptiveColor(light: 0xEBEDF0, dark: 0x3E464F)

    // One accent for primary actions, selections, switches and native sliders.
    static let controlTint = action
    static let controlForeground = adaptiveColor(light: 0xFFFFFF, dark: 0x1C2630)
    /// Fine pale edge for flat selected segments and primary actions.
    static let accentStroke = adaptiveColor(light: 0xFFFFFF, dark: 0xF0F4F8)
    /// Local neutral feedback; never a competing selection color.
    static let controlHover = textPrimary.opacity(0.07)
    static let controlPressed = textPrimary.opacity(0.12)
    static let selectedZoneFillTop = adaptiveColor(light: 0xDDE8FF, dark: 0x254C48)
    static let selectedZoneFillBottom = selectedZoneFillTop
    static let selectedTapFill = selectedZoneFillTop
    static let selectionBoundary = action
    static let selectedZoneCaptionFill = action
    static let selectedZoneCaptionForeground = adaptiveColor(light: 0xFFFFFF, dark: 0x1C2630)

    /// Sibling cards use the same rhythm horizontally and vertically.
    static let cardSpacing = Spacing.s4
    static let padColumnWidth = (Metrics.defaultContentWidth - cardSpacing) / 2
    static let sliderMinimumWidth: CGFloat = 120
    /// Combined toggle-and-slider rows retain the same inline width budget as a standard slider row.
    static let toggleSliderMinimumWidth: CGFloat = 72
    static let minimumPadSectionWidth = max(
        Width.control,
        sliderMinimumWidth + Spacing.s2 + Width.readout,
        Width.toggle + (2 * Spacing.s2) + toggleSliderMinimumWidth + Width.readout
    )
    static let minimumPadColumnWidth = previewInspectorColumnsBreakpoint
    static let previewInspectorSpacing = Spacing.s4
    static let previewInspectorColumnsBreakpoint = Metrics.zoneMapWidth
        + minimumPadSectionWidth + Spacing.s2
    static let behaviorPickerWidth = Width.control
}

private struct PaddrTypographyModifier: ViewModifier {
    let role: PaddrTextRole
    func body(content: Content) -> some View { content.font(role.font) }
}

/// A recessed panel for supporting content inside the workspace, such as the setup
/// checklist. It is the canvas colour on the workspace surface and is never glass:
/// glass belongs to the bars that float above the content.
private struct PaddrCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        PaddrAppearanceReader { appearance in
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(PaddrStyle.Inset.card)
                .background {
                    RoundedRectangle(cornerRadius: PaddrStyle.Radius.card)
                        .fill(appearance.surface(elevated: false))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: PaddrStyle.Radius.card)
                        .strokeBorder(
                            appearance.surfaceStroke,
                            lineWidth: appearance.strokeWidth
                        )
                        .allowsHitTesting(false)
                }
        }
    }
}

/// The surface of a bar that floats over the workspace: Liquid Glass, or an
/// opaque bordered fill when Reduce Transparency or Increase Contrast asks for one.
private struct PaddrBarSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        PaddrAppearanceReader { appearance in
            let shape = RoundedRectangle(cornerRadius: PaddrStyle.Radius.card)
            content
                .padding(.horizontal, PaddrStyle.Bar.inset)
                .padding(.vertical, PaddrStyle.Bar.verticalInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    if !appearance.usesChromeGlass {
                        shape.fill(appearance.surface(elevated: false))
                        shape.strokeBorder(appearance.surfaceStroke, lineWidth: appearance.strokeWidth)
                    }
                }
                .glassEffect(appearance.usesChromeGlass ? .regular : .identity, in: shape)
        }
    }
}

private struct PaddrActionButtonModifier: ViewModifier {
    let role: PaddrButtonRole

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .labelStyle(PaddrActionLabelStyle(role: role))
            .buttonStyle(PaddrButtonStyle(role: role))
            .focusEffectDisabled()
    }
}

extension View {
    func paddrTypography(_ role: PaddrTextRole) -> some View {
        modifier(PaddrTypographyModifier(role: role))
    }

    func paddrCard() -> some View { modifier(PaddrCardModifier()) }

    func paddrBarSurface() -> some View { modifier(PaddrBarSurfaceModifier()) }

    func paddrActionButton(_ role: PaddrButtonRole) -> some View {
        modifier(PaddrActionButtonModifier(role: role))
    }
}

private struct PaddrActionLabelStyle: LabelStyle {
    let role: PaddrButtonRole
    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if role == .icon { configuration.icon }
        else { HStack(spacing: PaddrStyle.Spacing.s1) { configuration.icon; configuration.title } }
    }
}
