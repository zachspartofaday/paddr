import AppKit
import SwiftUI

/// Applies measurements from the mounted editor; never creates a second editor
/// just to measure it, so disclosure state and focused controls remain intact.
struct ConfigurationWindowSizingView: NSViewRepresentable {
    let preferredHeight: CGFloat?

    func makeNSView(context: Context) -> ContentSizingView { ContentSizingView() }

    func updateNSView(_ view: ContentSizingView, context: Context) {
        view.preferredHeight = preferredHeight
        view.scheduleResize()
    }

    static func dismantleNSView(_ view: ContentSizingView, coordinator: ()) {
        view.stopObserving()
    }

    final class ContentSizingView: NSView {
        var preferredHeight: CGFloat?
        private var pendingResize: Task<Void, Never>?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopObserving()
            guard let window else { return }
            NotificationCenter.default.addObserver(self, selector: #selector(screenChanged),
                name: NSWindow.didChangeScreenNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(screenChanged),
                name: NSApplication.didChangeScreenParametersNotification, object: nil)
            scheduleResize()
        }

        @objc private func screenChanged() { scheduleResize() }

        func stopObserving() {
            pendingResize?.cancel()
            pendingResize = nil
            NotificationCenter.default.removeObserver(self)
        }

        func scheduleResize() {
            pendingResize?.cancel()
            // AppKit frame changes happen after SwiftUI's measurement transaction.
            pendingResize = Task { @MainActor [weak self] in
                await Task.yield()
                guard !Task.isCancelled, let self, let window,
                      let preferredHeight, preferredHeight.isFinite, preferredHeight > 0 else { return }
                PaddrFamilyWindowChrome.fitConfigurationWindow(window, preferredHeight: preferredHeight)
            }
        }
    }
}
