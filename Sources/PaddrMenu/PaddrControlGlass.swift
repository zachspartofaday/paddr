import SwiftUI

/// Primary accents are flat; secondary buttons retain native material and opaque fallbacks.
struct PaddrButtonSurface: View {
    let prominent: Bool
    let enabled: Bool
    let appearance: PaddrAppearance
    var body: some View {
        let shape = PaddrControlShape()
        if prominent {
            shape.fill(appearance.accentFill(enabled: enabled))
        } else if !appearance.usesControlGlass {
            shape.fill(PaddrStyle.workspace)
        } else {
            let materialInset = PaddrStyle.Control.materialInset
            let materialShape = PaddrControlShape(radius: PaddrStyle.Control.radius - materialInset)
            materialShape.fill(.clear)
                .glassEffect(Glass.regular.interactive(enabled && !appearance.reducesMotion), in: materialShape)
                .padding(materialInset)
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
