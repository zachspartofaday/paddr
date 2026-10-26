import SwiftUI

struct PanelBackgroundView: View {
    var body: some View {
        PaddrStyle.canvas
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
