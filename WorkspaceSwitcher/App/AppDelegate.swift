import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var updaterController: UpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock (also set in Info.plist via LSUIElement)
        NSApp.setActivationPolicy(.accessory)

        let store = WorkspaceStore.shared
        store.load()

        updaterController = UpdaterController()
        statusBarController = StatusBarController(store: store, updaterController: updaterController!)
    }

    func applicationWillTerminate(_ notification: Notification) {
        WorkspaceStore.shared.save()
    }
}
