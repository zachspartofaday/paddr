import SwiftUI

/// The same silhouette is used for drawing, clipping, pointer hit testing and focus.
struct PaddrPadShape: InsettableShape {
    var insetAmount: CGFloat = 0
    func inset(by amount: CGFloat) -> Self {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect.insetBy(dx: insetAmount, dy: insetAmount),
             cornerRadius: max(0, PaddrStyle.Radius.pad - insetAmount))
    }
}

struct PaddrPadSurface: ViewModifier {
    let appearance: PaddrAppearance
    func body(content: Content) -> some View {
        content
            .clipShape(PaddrPadShape())
            .overlay {
                if appearance.showsSurfaceDepth {
                    Canvas { context, size in
                        let path = PaddrPadShape().path(in: CGRect(origin: .zero, size: size))
                        context.clip(to: path)
                        context.addFilter(.shadow(color: .black.opacity(PaddrStyle.Depth.padRecessOpacity),
                            radius: PaddrStyle.Depth.padRecessRadius, y: PaddrStyle.Depth.padRecessOffset,
                            options: [.shadowOnly, .invertsAlpha]))
                        context.fill(path, with: .color(.black))
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .overlay {
                PaddrPadShape()
                    .strokeBorder(appearance.hasIncreasedContrast ? PaddrStyle.textPrimary : PaddrStyle.textSecondary,
                                  lineWidth: appearance.hasIncreasedContrast ? 2 : 1.5)
                    .allowsHitTesting(false)
            }
    }
}

/// Expanding the focus path also grows its radius: both curves retain the same
/// corner centers. The ring is outside selection and does not change hit geometry.
struct PaddrPadFocusRing: View {
    static let outset: CGFloat = 4
    var body: some View {
        PaddrPadShape(insetAmount: -Self.outset)
            .stroke(PaddrStyle.action, style: StrokeStyle(lineWidth: 2,
                lineCap: .round, lineJoin: .round, dash: [4, 3]))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
