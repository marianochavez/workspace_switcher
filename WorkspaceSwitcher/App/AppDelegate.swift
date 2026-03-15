import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock (also set in Info.plist via LSUIElement)
        NSApp.setActivationPolicy(.accessory)

        let store = WorkspaceStore.shared
        store.load()

        statusBarController = StatusBarController(store: store)
    }

    func applicationWillTerminate(_ notification: Notification) {
        WorkspaceStore.shared.save()
    }
}
