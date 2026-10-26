import SwiftUI

/// The same silhouette is used for drawing, clipping, pointer hit testing and focus.
struct PaddrPadShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: PaddrStyle.Radius.pad)
    }
}

struct PaddrPadSurface: ViewModifier {
    let appearance: PaddrAppearance
    func body(content: Content) -> some View {
        content
            .clipShape(PaddrPadShape())
            .overlay {
                PaddrPadShape()
                    .stroke(appearance.hasIncreasedContrast ? PaddrStyle.textPrimary : PaddrStyle.textSecondary,
                            lineWidth: appearance.hasIncreasedContrast ? 1.5 : 1)
                    .padding(0.75)
                    .allowsHitTesting(false)
            }
    }
}
