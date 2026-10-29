import SwiftUI
import PaddrCore

struct TapActionPicker: View {
    @Binding var selection: String?

    var body: some View {
        PaddrSettingsRow(title: "Touch tap", systemImage: "hand.tap") {
            OptionalOutputBindingPicker(selection: $selection, title: "Touch tap action")
        }
        .help("Click a mouse button or emit a keyboard key after a short touch and release.")
    }
}

/// Native optional output menu shared by touch taps and rear buttons.
struct OptionalOutputBindingPicker: View {
    @Binding var selection: String?
    let title: LocalizedStringResource
    var width: CGFloat = PaddrStyle.Width.control
    var accessibilityIdentifier: String?

    var customSelection: String? {
        guard let selection,
              !TapBindingCatalog.isMouseButton(selection),
              !KeyCatalog.commonNames.contains(selection)
        else { return nil }
        return selection
    }

    private var options: [PaddrMenuOption<String?>] {
        var result: [PaddrMenuOption<String?>] = [.init(value: .some(nil), title: String(localized: "None"))]
        if let customSelection {
            result.append(.init(value: .some(customSelection), title: OutputBindingText.string(for: customSelection)))
        }
        result += [
            .separator,
            .init(value: .some(TapBindingCatalog.leftMouseButton), title: String(localized: "Left click"), systemImage: "computermouse.fill"),
            .init(value: .some(TapBindingCatalog.rightMouseButton), title: String(localized: "Right click"), systemImage: "computermouse"),
            .separator
        ]
        result += KeyCatalog.commonNames.map { .init(value: .some($0), title: OutputBindingText.string(for: $0)) }
        return result
    }

    var body: some View {
        PaddrMenuPicker(title: title, selection: $selection, options: options, width: width,
            accessibilityIdentifier: accessibilityIdentifier)
    }
}
