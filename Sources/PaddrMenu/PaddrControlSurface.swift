import SwiftUI

/// Controls in the workspace are opaque in every appearance: a flat accent for the
/// primary action and one shared fill for everything else. Liquid Glass belongs to
/// the bars that float above the workspace, not to the controls inside it.
struct PaddrButtonSurface: View {
    let prominent: Bool
    let enabled: Bool
    let appearance: PaddrAppearance
    var body: some View {
        PaddrControlShape()
            .fill(prominent ? appearance.accentFill(enabled: enabled) : PaddrStyle.controlFill)
    }
}

/// The same continuous silhouette for normal and outward focus geometry.
struct PaddrControlShape: InsettableShape {
    var radius: CGFloat = PaddrStyle.Control.radius
    var insetAmount: CGFloat = 0
    func inset(by amount: CGFloat) -> Self {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: max(0, radius - insetAmount), style: .continuous)
            .path(in: rect.insetBy(dx: insetAmount, dy: insetAmount))
    }
}
