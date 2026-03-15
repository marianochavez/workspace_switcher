import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let store: WorkspaceStore
    private var settingsWindowController: SettingsWindowController?

    init(store: WorkspaceStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        store.onChange = { [weak self] in
            DispatchQueue.main.async { self?.rebuildMenu() }
        }
        rebuildMenu()
    }

    // MARK: - Icon

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        if let active = store.activeWorkspace {
            switch active.icon {
            case .emoji(let e):
                button.image = nil
                button.title = e
            case .sfSymbol(let name):
                button.title = ""
                button.image = NSImage(systemSymbolName: name, accessibilityDescription: active.name)
            }
        } else {
            button.title = ""
            button.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "WorkspaceSwitcher")
        }
    }

    // MARK: - Menu

    func rebuildMenu() {
        updateIcon()
        let menu = MenuBuilder.build(
            store: store,
            onSwitch: { [weak self] workspace in
                guard let self else { return }
                SwitcherService.switchAndNotify(workspace: workspace, store: self.store)
            },
            onSettings: { [weak self] in
                self?.openSettings()
            }
        )
        statusItem.menu = menu
    }

    // MARK: - Settings

    private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(store: store)
            settingsWindowController?.onClose = { [weak self] in
                self?.settingsWindowController = nil
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }
}
