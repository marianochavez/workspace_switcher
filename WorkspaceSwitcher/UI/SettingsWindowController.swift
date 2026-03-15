import AppKit

final class SettingsWindowController: NSWindowController {
    var onClose: (() -> Void)?
    private let store: WorkspaceStore

    init(store: WorkspaceStore) {
        self.store = store
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.minSize = NSSize(width: 560, height: 420)
        window.center()
        super.init(window: window)

        let vc = SettingsViewController(store: store)
        window.contentViewController = vc
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
