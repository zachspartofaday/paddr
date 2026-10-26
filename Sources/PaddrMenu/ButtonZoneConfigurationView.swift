import PaddrAppSupport
import SwiftUI
import PaddrCore

struct ButtonZoneConfigurationView: View {
    @Binding var configuration: PadConfiguration
    let isEditable: Bool
    @State private var selectedZone: ButtonZone

    init(configuration: Binding<PadConfiguration>, isEditable: Bool = true) {
        self.isEditable = isEditable
        _configuration = configuration
        _selectedZone = State(
            initialValue: configuration.wrappedValue.zoneLayout.zones[0]
        )
    }

    var body: some View {
        PaddrAdaptiveSplitView(
            breakpoint: PaddrStyle.previewInspectorColumnsBreakpoint,
            leadingWidth: PaddrStyle.Metrics.zoneMapWidth,
            showsDivider: false,
            alignsPadInspector: true,
            leading: { mapSection },
            trailing: { inspector }
        )
        .onChange(of: configuration.zoneLayout) { _, layout in
            selectedZone = ZoneSelectionPolicy.normalized(selectedZone, for: layout)
        }
    }

    private var padMap: some View {
        ZonePadMap(
            layout: configuration.zoneLayout,
            deadzone: configuration.dpadDeadzone,
            configuration: configuration,
            selection: $selectedZone
        )
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            padMap
                .frame(
                    width: PaddrStyle.Metrics.zoneMapWidth,
                    height: PaddrStyle.Metrics.zoneMapHeight
                )
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            PaddrSettingsRow(title: "Layout", systemImage: "square.grid.2x2") {
                areaLayoutPicker.disabled(!isEditable)
            }

            PaddrSettingsRow(title: "Selected area", systemImage: selectedZone.systemImage) {
                selectedAreaPicker
            }

            PaddrSettingsRow(title: "Action", systemImage: "keyboard") {
                OutputBindingPicker(
                    selection: $configuration[bindingFor: selectedZone],
                    width: PaddrStyle.Width.control
                )
                .disabled(!isEditable)
            }

            if configuration.zoneLayout != .gridNine {
                PaddrSettingsRow(title: "Neutral zone", systemImage: "circle.dotted") {
                    HStack(spacing: PaddrStyle.Spacing.s2) {
                        Slider(
                            value: $configuration.dpadDeadzone.quantized(
                                step: 0.01,
                                in: 0...Double(1).nextDown
                            ),
                            in: 0...Double(1).nextDown
                        )
                        .disabled(!isEditable)
                        .accessibilityLabel("Neutral zone size")
                        .accessibilityValue(
                            configuration.dpadDeadzone.formatted(.percent.precision(.fractionLength(0)))
                        )
                        .help("Touches inside the neutral zone do not emit an action.")
                        Text(configuration.dpadDeadzone.formatted(.percent.precision(.fractionLength(0))))
                            .paddrTypography(.value)
                            .foregroundStyle(PaddrStyle.textSecondary)
                            .frame(width: PaddrStyle.Width.readout, alignment: .trailing)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .environment(\.paddrStacksSettingLabels, true)
        .accessibilityElement(children: .contain)
    }

    private var areaLayoutPicker: some View {
        PaddrMenuPicker(title: "Area layout", selection: $configuration.zoneLayout,
            options: PadZoneLayout.allCases.map {
                .init(value: $0, title: String(localized: $0.displayName))
            })
        .help("Choose how the trackpad is divided into button areas.")
    }

    private var selectedAreaPicker: some View {
        PaddrMenuPicker(title: "Selected area", selection: $selectedZone,
            options: configuration.zoneLayout.zones.map {
                .init(value: $0, title: String(localized: $0.title), systemImage: $0.systemImage)
            }, accessibilityIdentifier: PaddrAccessibility.identifier("zones", "selected-area"))
        .help("Choose the trackpad area to configure.")
    }
}

extension ButtonZone {
    var title: LocalizedStringResource {
        switch self {
        case .topLeft: LocalizedStringResource("Top left")
        case .up: LocalizedStringResource("Top")
        case .topRight: LocalizedStringResource("Top right")
        case .left: LocalizedStringResource("Left")
        case .center: LocalizedStringResource("Center")
        case .right: LocalizedStringResource("Right")
        case .bottomLeft: LocalizedStringResource("Bottom left")
        case .down: LocalizedStringResource("Bottom")
        case .bottomRight: LocalizedStringResource("Bottom right")
        }
    }

    var systemImage: String {
        switch self {
        case .topLeft: "arrow.up.left"
        case .up: "arrow.up"
        case .topRight: "arrow.up.right"
        case .left: "arrow.left"
        case .center: "circle"
        case .right: "arrow.right"
        case .bottomLeft: "arrow.down.left"
        case .down: "arrow.down"
        case .bottomRight: "arrow.down.right"
        }
    }
}
