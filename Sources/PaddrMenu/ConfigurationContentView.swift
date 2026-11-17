import PaddrAppSupport
import SwiftUI

/// The complete scroll document, kept as one production surface so rendered layout
/// tests can measure it independently from AppKit's scroll-view implementation.
/// It sits directly on the window surface; nothing encloses it.
struct ConfigurationContentView: View {
    @Bindable var model: PaddrMenuModel
    let commands: ProfileCommands
    var setupGuide: SetupGuidePresentation?
    var initialTuningExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.cardSpacing) {
            if let setupGuide, setupGuide.isPresented {
                SetupChecklistView(model: model, commands: commands) { setupGuide.dismiss(as: $0) }
            } else if model.activeProfileID == .default {
                // The checklist carries the same notice as its profile step.
                ReadOnlyProfileNotice(model: model, commands: commands)
                Divider()
            }
            DualPadConfigurationView(
                configuration: $model.configuration,
                appearsEnabled: model.activeProfileControlsAppearEnabled,
                isEditable: model.canEditActiveProfile,
                initialTuningExpanded: initialTuningExpanded
            )
            Divider()
            RearButtonConfigurationView(
                configuration: $model.configuration.rearButtons,
                isEditable: model.canEditActiveProfile
            )
            Divider()
            ControllerSensorsConfigurationView(
                gyro: $model.configuration.gyro,
                gripTouch: $model.configuration.gripTouch,
                sensorStatus: model.sensorStatus,
                isEditable: model.canEditActiveProfile,
                isOutputEnabled: model.isEnabled,
                savedGyroEnabled: model.savedConfiguration.gyro.enabled,
                canRecalibrate: model.canRecalibrateGyro,
                calibrationUnavailableReason: model.gyroCalibrationUnavailableReason,
                recalibrate: { model.requestGyroCalibration() }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PaddrStyle.Inset.window)
        .padding(.vertical, PaddrStyle.Inset.section)
    }
}
