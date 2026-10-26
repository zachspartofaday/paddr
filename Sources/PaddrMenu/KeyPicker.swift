import SwiftUI
import PaddrCore

struct OutputBindingPicker: View {
    @Binding var selection: String
    var width: CGFloat = PaddrStyle.Width.control

    private var keyChoices: [String] {
        if TapBindingCatalog.isMouseButton(selection) || KeyCatalog.commonNames.contains(selection) {
            return KeyCatalog.commonNames
        }
        return [selection] + KeyCatalog.commonNames
    }

    private var options: [PaddrMenuOption<String>] {
        [
            .init(value: TapBindingCatalog.leftMouseButton, title: String(localized: "Left click"), systemImage: "computermouse.fill"),
            .init(value: TapBindingCatalog.rightMouseButton, title: String(localized: "Right click"), systemImage: "computermouse"),
            .separator
        ] + keyChoices.map { .init(value: $0, title: OutputBindingText.string(for: $0)) }
    }

    var body: some View {
        PaddrMenuPicker(title: "Zone action", selection: $selection, options: options, width: width)
        .accessibilityLabel("Zone action")
        .help("Assign a keyboard key, left click, or right click to this touch area.")
    }
}
