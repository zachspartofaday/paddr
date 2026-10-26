import PaddrCore
import SwiftUI

/// Keeps both trackpad editors mounted together. The adaptive layout moves the
/// same two subtrees between columns and rows without duplicating editor state.
struct DualPadConfigurationView: View {
    @Binding var configuration: PaddrConfiguration
    let appearsEnabled: Bool
    let isEditable: Bool
    var initialTuningExpanded = false

    var body: some View {
        PaddrAdaptiveSplitView(
            columnsBreakpoint: PaddrStyle.Metrics.padEditorColumnsBreakpoint,
            leading: {
                PadConfigurationView(
                    side: .left,
                    configuration: $configuration.left,
                    isEditable: isEditable,
                    initialTuningExpanded: initialTuningExpanded
                )
                .paddrAccessibilityID("pad-editor", "left")
            },
            trailing: {
                PadConfigurationView(
                    side: .right,
                    configuration: $configuration.right,
                    isEditable: isEditable,
                    initialTuningExpanded: initialTuningExpanded
                )
                .paddrAccessibilityID("pad-editor", "right")
            }
        )
    }
}
