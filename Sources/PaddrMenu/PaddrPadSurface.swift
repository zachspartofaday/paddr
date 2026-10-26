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
        // Match the circular CGPath used by selected-zone outlines. Explicit
        // arcs also avoid continuous-path stroke spikes at corner tangencies.
        Path(roundedRect: rect.insetBy(dx: insetAmount, dy: insetAmount),
             cornerRadius: max(0, PaddrStyle.Radius.pad - insetAmount), style: .circular)
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
                        // Give the blur a real exterior on all four sides. Inverting
                        // alpha at the Canvas bounds truncates that exterior and
                        // produces seams where the corners meet straight edges.
                        let reach = 4 * PaddrStyle.Depth.padRecessRadius + PaddrStyle.Depth.padRecessOffset
                        var exterior = Path(CGRect(origin: .zero, size: size).insetBy(dx: -reach, dy: -reach))
                        exterior.addPath(path)
                        context.addFilter(.shadow(color: .black.opacity(PaddrStyle.Depth.padRecessOpacity),
                            radius: PaddrStyle.Depth.padRecessRadius, y: PaddrStyle.Depth.padRecessOffset,
                            options: .shadowOnly))
                        context.fill(exterior, with: .color(.black), style: FillStyle(eoFill: true))
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .overlay {
                PaddrPadShape()
                    .strokeBorder(appearance.hasIncreasedContrast ? PaddrStyle.textPrimary : PaddrStyle.textSecondary,
                                  lineWidth: appearance.hasIncreasedContrast ? 2 : 1)
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
