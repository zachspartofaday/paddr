import PaddrAppSupport
import SwiftUI

/// The complete scroll document, kept as one production surface so rendered layout tests
/// can measure card enclosure independently from AppKit's scroll-view implementation.
struct ConfigurationContentView: View {
    @Bindable var model: PaddrMenuModel
    var initialTuningExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.cardSpacing) {
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
        .paddrCard()
        .padding(PaddrStyle.Inset.window)
    }
}
