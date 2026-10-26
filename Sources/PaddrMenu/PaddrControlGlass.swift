import SwiftUI

/// SwiftUI buttons share the same material and opaque accessibility fallback.
struct PaddrButtonSurface: View {
    let prominent: Bool
    let enabled: Bool
    let appearance: PaddrAppearance
    var body: some View {
        let shape = PaddrControlShape()
        if !appearance.usesControlGlass {
            shape.fill(prominent ? PaddrStyle.controlTint : PaddrStyle.workspace)
        } else {
            let materialShape = PaddrControlShape(radius: PaddrStyle.Control.radius - PaddrStyle.Control.materialInset)
            materialShape.fill(.clear)
                .glassEffect((prominent ? Glass.clear.tint(PaddrStyle.controlTint) : Glass.regular)
                    .interactive(enabled && !appearance.reducesMotion), in: materialShape)
                // The native material edge sits under the opaque structural rim,
                // rather than competing with a second fractional outline.
                .padding(PaddrStyle.Control.materialInset)
                .background {
                    // Prominent color is beneath the clear native glass pass;
                    // it never paints over and hides the material.
                    if prominent { shape.fill(PaddrStyle.controlTint) }
                }
        }
    }
}

private struct PaddrControlMaterial: ViewModifier {
    @Environment(\.self) private var environment
    let isSwitch: Bool
    func body(content: Content) -> some View {
        content.background {
            PaddrButtonSurface(prominent: false, enabled: environment.isEnabled,
                appearance: PaddrAppearance(environment: environment))
                .frame(width: isSwitch ? PaddrStyle.Control.TuningSwitch.track.width : nil,
                       height: isSwitch ? PaddrStyle.Control.TuningSwitch.track.height : nil)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    func paddrControlMaterial(isSwitch: Bool = false) -> some View {
        modifier(PaddrControlMaterial(isSwitch: isSwitch))
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
