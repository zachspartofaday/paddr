import SwiftUI

struct PaddrButtonStyle: ButtonStyle {
    let role: PaddrButtonRole
    func makeBody(configuration: Configuration) -> some View {
        Chrome(configuration: configuration, role: role)
    }

    private struct Chrome: View {
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @Environment(\.self) private var environment
        @State private var isHovered = false
        let configuration: ButtonStyle.Configuration
        let role: PaddrButtonRole

        private var appearance: PaddrAppearance { PaddrAppearance(environment: environment) }

        var body: some View {
            configuration.label
                .paddrTypography(.rowLabel)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, role == .icon ? 0 : PaddrStyle.Control.sideInset)
                .padding(.vertical, 6)
                .frame(minWidth: role == .icon ? PaddrStyle.Control.height : nil,
                       minHeight: PaddrStyle.Control.height)
                .foregroundStyle(role == .primary
                    ? appearance.accentForeground(enabled: isEnabled) : PaddrStyle.textPrimary)
                .background {
                    PaddrButtonSurface(prominent: role == .primary, enabled: isEnabled, appearance: appearance)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .overlay {
                    PaddrControlShape()
                        .fill(isEnabled && configuration.isPressed ? PaddrStyle.controlPressed
                            : isHovered && isEnabled ? PaddrStyle.controlHover : .clear)
                        .allowsHitTesting(false)
                }
                .overlay {
                    PaddrControlShape()
                        .strokeBorder(role == .primary ? appearance.accentStroke(enabled: isEnabled)
                            : appearance.controlStroke(enabled: isEnabled),
                            lineWidth: role == .primary ? appearance.strokeWidth : PaddrStyle.Control.outlineWidth)
                        .allowsHitTesting(false)
                }
                .overlay {
                    if isFocused {
                        PaddrControlShape(insetAmount: -3)
                            .strokeBorder(PaddrStyle.action, lineWidth: PaddrStyle.Control.focusWidth)
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(PaddrControlShape())
                .opacity(isEnabled ? 1 : 0.55)
                .onHover { isHovered = $0 }
        }
    }
}
