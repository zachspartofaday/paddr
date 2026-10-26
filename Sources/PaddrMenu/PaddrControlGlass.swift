import SwiftUI

/// SwiftUI buttons share the same material and opaque accessibility fallback.
struct PaddrButtonSurface: View {
    let prominent: Bool
    let enabled: Bool
    let appearance: PaddrAppearance
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PaddrStyle.Control.radius, style: .continuous)
        if !appearance.usesControlGlass {
            shape.fill(prominent ? PaddrStyle.controlTint : PaddrStyle.workspace)
        } else {
            shape.fill(.clear)
                .glassEffect(.regular.interactive(enabled && !appearance.reducesMotion), in: shape)
                .overlay {
                    // Stable contrast for prominent text, with native glass edge/light
                    // still visible. This is a semantic fill, not synthetic lighting.
                    if prominent { shape.inset(by: 1.5).fill(PaddrStyle.controlTint) }
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
