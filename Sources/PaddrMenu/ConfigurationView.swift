import PaddrAppSupport
import SwiftUI

struct ConfigurationView: View {
    @Bindable var model: PaddrMenuModel
    // Fixed-size fixture hosts opt out; the application's window always opts in.
    var managesWindowSize = false
    var initialTuningExpanded = false
    @State private var headerHeight: CGFloat = 0
    @State private var documentHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    private var preferredHeight: CGFloat? {
        guard headerHeight > 0, documentHeight > 0, footerHeight > 0 else { return nil }
        return ceil(headerHeight + documentHeight + footerHeight + 1)
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: 0) {
                TopControlsView(model: model)
                    .padding(.horizontal, PaddrStyle.Inset.chrome)
                    .padding(.vertical, PaddrStyle.Spacing.s3)
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { headerHeight = $0 }
                Divider()
                ScrollView {
                    ConfigurationContentView(model: model, initialTuningExpanded: initialTuningExpanded)
                        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { documentHeight = $0 }
                }
                .scrollIndicators(.automatic)

                ApplyBarView(model: model)
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { footerHeight = $0 }
            }
        }
        .background {
            if managesWindowSize {
                ConfigurationWindowSizingView(preferredHeight: preferredHeight)
            }
        }
        .paddrTypography(.rowLabel)
        .foregroundStyle(PaddrStyle.textPrimary)
        .controlSize(.regular)
        .tint(PaddrStyle.controlTint)
        .toolbar {
            ToolbarSpacer(.flexible)

            ToolbarItemGroup(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise", action: model.refreshStatus)
                    .labelStyle(.iconOnly)
                    .help("Refresh controller and permission status")
                    .paddrAccessibilityID("toolbar", "refresh")
            }
        }
    }
}
