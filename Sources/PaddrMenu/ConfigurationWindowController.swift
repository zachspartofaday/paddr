import AppKit
import PaddrAppSupport
import SwiftUI

/// Owns the configuration window and what closing it means. Setup used to be a
/// window of its own, and closing that ended automatic setup; closing this one
/// does the same.
@MainActor
final class ConfigurationWindowController: NSWindowController, NSWindowDelegate {
    private let setupGuide: SetupGuidePresentation
    private let didClose: @MainActor (NSWindow) -> Void

    init(
        model: PaddrMenuModel,
        setupGuide: SetupGuidePresentation,
        didClose: @escaping @MainActor (NSWindow) -> Void
    ) {
        self.setupGuide = setupGuide
        self.didClose = didClose
        let window = PaddrFamilyWindowChrome.makeConfigurationWindow(
            rootView: ConfigurationView(model: model, managesWindowSize: true, setupGuide: setupGuide)
        )
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ConfigurationWindowController is created in code")
    }

    func windowWillClose(_ notification: Notification) {
        guard let window else { return }
        setupGuide.windowDidClose()
        didClose(window)
    }
}
