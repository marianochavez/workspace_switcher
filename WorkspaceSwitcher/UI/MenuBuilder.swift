import AppKit
import Sparkle

struct MenuBuilder {
    static func build(
        store: WorkspaceStore,
        updaterController: UpdaterController? = nil,
        onSwitch: @escaping (Workspace) -> Void,
        onSettings: @escaping () -> Void
    ) -> NSMenu {
        let menu = NSMenu()

        if store.workspaces.isEmpty {
            let empty = NSMenuItem(title: "No workspaces — open Settings", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for workspace in store.workspaces {
                let item = WorkspaceMenuItem(workspace: workspace, onSwitch: onSwitch)
                item.state = workspace.id == store.activeWorkspaceID ? .on : .off
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let settingsAction = SettingsAction(handler: onSettings)
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(SettingsAction.run), keyEquivalent: ",")
        settingsItem.representedObject = settingsAction
        settingsItem.target = settingsAction
        menu.addItem(settingsItem)

        if let updaterController {
            let updateItem = NSMenuItem(
                title: "Check for Updates…",
                action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
                keyEquivalent: ""
            )
            updateItem.target = updaterController.updaterController
            menu.addItem(updateItem)
        }

        let quitItem = NSMenuItem(title: "Quit WorkspaceSwitcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        return menu
    }
}

// MARK: - Custom menu item with closure

private final class WorkspaceMenuItem: NSMenuItem {
    private let workspace: Workspace
    private let onSwitch: (Workspace) -> Void
    private var selfRef: WorkspaceMenuItem?

    init(workspace: Workspace, onSwitch: @escaping (Workspace) -> Void) {
        self.workspace = workspace
        self.onSwitch = onSwitch

        switch workspace.icon {
        case .emoji(let e):
            let title = "\(e)  \(workspace.name)"
            super.init(title: title, action: #selector(WorkspaceMenuItem.activate), keyEquivalent: "")
        case .sfSymbol(let name):
            super.init(title: workspace.name, action: #selector(WorkspaceMenuItem.activate), keyEquivalent: "")
            self.image = NSImage(systemSymbolName: name, accessibilityDescription: workspace.name)?
                .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
        }

        self.target = self
        self.selfRef = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func activate() {
        onSwitch(workspace)
    }
}

// MARK: - Settings action trampoline

private final class SettingsAction: NSObject {
    private let handler: () -> Void
    init(handler: @escaping () -> Void) { self.handler = handler }
    @objc func run() { handler() }
}
