import AppKit
import SwiftUI

/// Shows unsaved changes the way a document window does: the dot in the close
/// button, and "Edited" beside the title.
struct ConfigurationWindowDocumentState: NSViewRepresentable {
    let isEdited: Bool

    func makeNSView(context: Context) -> StateView { StateView() }

    func updateNSView(_ view: StateView, context: Context) {
        view.isEdited = isEdited
    }

    final class StateView: NSView {
        var isEdited = false {
            didSet { apply() }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        private func apply() {
            guard let window else { return }
            PaddrFamilyWindowChrome.setDocumentEdited(isEdited, for: window)
        }
    }
}
