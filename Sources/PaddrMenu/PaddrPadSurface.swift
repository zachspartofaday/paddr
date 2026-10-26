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
                PaddrPadShape()
                    .strokeBorder(appearance.hasIncreasedContrast ? PaddrStyle.textPrimary : PaddrStyle.textSecondary,
                                  lineWidth: appearance.hasIncreasedContrast ? 2 : 1.5)
                    .allowsHitTesting(false)
            }
    }
}
