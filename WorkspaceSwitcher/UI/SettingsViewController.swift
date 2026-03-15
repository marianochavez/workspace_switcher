import AppKit

protocol WorkspaceSidebarDelegate: AnyObject {
    func sidebarDidSelectWorkspace(_ workspace: Workspace)
    func sidebarDidClearSelection()
}

final class SettingsViewController: NSSplitViewController {
    private let store: WorkspaceStore
    private let sidebarVC: WorkspaceSidebarViewController
    private let detailVC: WorkspaceDetailViewController

    init(store: WorkspaceStore) {
        self.store = store
        self.sidebarVC = WorkspaceSidebarViewController(store: store)
        self.detailVC = WorkspaceDetailViewController(store: store)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        sidebarVC.delegate = self
        detailVC.onWorkspaceUpdated = { [weak self] in
            self?.sidebarVC.reloadData()
        }

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 260

        let detailItem = NSSplitViewItem(contentListWithViewController: detailVC)
        detailItem.minimumThickness = 320

        addSplitViewItem(sidebarItem)
        addSplitViewItem(detailItem)
    }
}

extension SettingsViewController: WorkspaceSidebarDelegate {
    func sidebarDidSelectWorkspace(_ workspace: Workspace) {
        detailVC.showWorkspace(workspace)
    }

    func sidebarDidClearSelection() {
        detailVC.showPlaceholder()
    }
}
