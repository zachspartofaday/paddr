import PaddrAppSupport
import SwiftUI

struct ConfigurationView: View {
    @Bindable var model: PaddrMenuModel
    // Fixed-size fixture hosts opt out; the application's window always opts in.
    var managesWindowSize = false
    var initialTuningExpanded = false
    var setupGuide: SetupGuidePresentation?
    @State private var commands = ProfileCommands()
    @State private var documentHeight: CGFloat = 0
    @State private var barHeight: CGFloat = 0

    /// The bar floats over the bottom of the document, so a window that shows
    /// everything is as tall as the document plus the bar.
    private var preferredHeight: CGFloat? {
        guard documentHeight > 0, barHeight > 0 else { return nil }
        return ceil(documentHeight + barHeight)
    }

    var body: some View {
        ScrollView {
            ConfigurationContentView(
                model: model, commands: commands, setupGuide: setupGuide,
                initialTuningExpanded: initialTuningExpanded
            )
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { documentHeight = $0 }
        }
        .scrollIndicators(.automatic)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            ApplyBarView(model: model, showsPermissionNotice: setupGuide?.isPresented != true)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { barHeight = $0 }
        }
        .background { PanelBackgroundView() }
        .background {
            if managesWindowSize {
                ConfigurationWindowSizingView(preferredHeight: preferredHeight)
            }
        }
        .background { ConfigurationWindowDocumentState(isEdited: model.hasUnsavedChanges) }
        .paddrTypography(.rowLabel)
        .foregroundStyle(PaddrStyle.textPrimary)
        .controlSize(.regular)
        .tint(PaddrStyle.controlTint)
        .toolbar { ConfigurationToolbar(model: model, commands: commands) }
        .profileDialogs(model: model, commands: commands)
    }
}
