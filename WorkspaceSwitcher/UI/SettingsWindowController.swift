import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    var onClose: (() -> Void)?
    private let store: WorkspaceStore

    init(store: WorkspaceStore) {
        self.store = store
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.minSize = NSSize(width: 580, height: 440)
        window.center()
        super.init(window: window)

        let settingsView = SettingsContentView(store: store)
        window.contentView = NSHostingView(rootView: settingsView)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
