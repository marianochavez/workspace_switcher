import AppKit
import ServiceManagement

final class WorkspaceSidebarViewController: NSViewController {
    weak var delegate: WorkspaceSidebarDelegate?
    private let store: WorkspaceStore

    private var tableView: NSTableView!
    private var loginCheckbox: NSButton!

    private let cellID = NSUserInterfaceItemIdentifier("WorkspaceCell")

    init(store: WorkspaceStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        setupUI()
    }

    private func setupUI() {
        // Launch at login checkbox
        loginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(toggleLaunchAtLogin))
        loginCheckbox.font = .systemFont(ofSize: 11)
        loginCheckbox.state = launchAtLoginEnabled ? .on : .off
        loginCheckbox.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loginCheckbox)

        // Top separator
        let topSep = NSBox()
        topSep.boxType = .separator
        topSep.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topSep)

        // Table view
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 30
        tableView.dataSource = self
        tableView.delegate = self
        tableView.selectionHighlightStyle = .regular
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        col.isEditable = false
        tableView.addTableColumn(col)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Bottom separator
        let botSep = NSBox()
        botSep.boxType = .separator
        botSep.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(botSep)

        // Bottom toolbar with +/− segmented control
        let segmented = NSSegmentedControl(images: [
            NSImage(systemSymbolName: "plus", accessibilityDescription: "Add")!,
            NSImage(systemSymbolName: "minus", accessibilityDescription: "Remove")!
        ], trackingMode: .momentary, target: self, action: #selector(toolbarAction(_:)))
        segmented.segmentStyle = .smallSquare
        segmented.setWidth(28, forSegment: 0)
        segmented.setWidth(28, forSegment: 1)
        segmented.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmented)

        NSLayoutConstraint.activate([
            loginCheckbox.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            loginCheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            loginCheckbox.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -6),
            loginCheckbox.heightAnchor.constraint(equalToConstant: 20),

            topSep.topAnchor.constraint(equalTo: loginCheckbox.bottomAnchor, constant: 8),
            topSep.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topSep.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: topSep.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            botSep.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
            botSep.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            botSep.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            segmented.topAnchor.constraint(equalTo: botSep.bottomAnchor, constant: 4),
            segmented.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            segmented.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
            segmented.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    // MARK: - Public

    func reloadData() {
        tableView.reloadData()
    }

    func selectWorkspace(at index: Int) {
        guard index >= 0, index < store.workspaces.count else { return }
        tableView.selectRowIndexes([index], byExtendingSelection: false)
        delegate?.sidebarDidSelectWorkspace(store.workspaces[index])
    }

    // MARK: - Actions

    @objc private func toolbarAction(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            addWorkspace()
        } else {
            removeWorkspace()
        }
    }

    private func addWorkspace() {
        let ws = Workspace(name: "New Workspace")
        store.addWorkspace(ws)
        tableView.reloadData()
        selectWorkspace(at: store.workspaces.count - 1)
    }

    private func removeWorkspace() {
        let row = tableView.selectedRow
        guard row >= 0, row < store.workspaces.count else { return }
        let name = store.workspaces[row].name

        let alert = NSAlert()
        alert.messageText = "Delete \"\(name)\"?"
        alert.informativeText = "This will remove the workspace and all its account associations. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].hasDestructiveAction = true

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        store.deleteWorkspace(id: store.workspaces[row].id)
        tableView.reloadData()
        delegate?.sidebarDidClearSelection()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        setLaunchAtLogin(sender.state == .on)
    }

    // MARK: - Launch at Login

    private var launchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enable { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

// MARK: - NSTableViewDataSource / Delegate

extension WorkspaceSidebarViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        store.workspaces.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let ws = store.workspaces[row]

        var cell = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView
        if cell == nil {
            let c = NSTableCellView()
            c.identifier = cellID

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            c.addSubview(imageView)
            c.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            c.addSubview(textField)
            c.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 4),
                imageView.centerYAnchor.constraint(equalTo: c.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 18),
                imageView.heightAnchor.constraint(equalToConstant: 18),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            ])

            cell = c
        }

        cell?.textField?.stringValue = ws.name
        cell?.imageView?.image = ws.icon.nsImage
        if case .sfSymbol = ws.icon {
            cell?.imageView?.contentTintColor = .labelColor
        } else {
            cell?.imageView?.contentTintColor = nil
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < store.workspaces.count else {
            delegate?.sidebarDidClearSelection()
            return
        }
        delegate?.sidebarDidSelectWorkspace(store.workspaces[row])
    }
}
