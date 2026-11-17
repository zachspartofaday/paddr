import SwiftUI

/// The window surface. The mapping workspace sits directly on it; the pads are
/// the recessed surfaces inside it.
struct PanelBackgroundView: View {
    var body: some View {
        PaddrStyle.workspace
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
