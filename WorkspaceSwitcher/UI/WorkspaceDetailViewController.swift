import AppKit

final class WorkspaceDetailViewController: NSViewController {
    private let store: WorkspaceStore
    private var workspace: Workspace?

    var onWorkspaceUpdated: (() -> Void)?

    // Retained references
    private var contentContainer: NSView?
    private var placeholderLabel: NSTextField?
    private var sheetController: AddAccountSheetController?

    private var nameField: NSTextField!
    private var iconButton: NSButton!
    private var accountsTableView: NSTableView!
    private var claudeLoginBtn: NSButton!
    private var githubLoginBtn: NSButton!
    private var activeLoginProcess: CancellableProcess?

    private let accountCellID = NSUserInterfaceItemIdentifier("AccountCell")

    init(store: WorkspaceStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        showPlaceholder()
    }

    // MARK: - Public

    func showWorkspace(_ workspace: Workspace) {
        self.workspace = workspace
        tearDown()
        setupDetailUI()
    }

    func showPlaceholder() {
        workspace = nil
        tearDown()

        let label = NSTextField(labelWithString: "Select or add a workspace")
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        placeholderLabel = label

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func tearDown() {
        placeholderLabel?.removeFromSuperview()
        placeholderLabel = nil
        contentContainer?.removeFromSuperview()
        contentContainer = nil
    }

    // MARK: - Detail UI

    private func setupDetailUI() {
        guard let workspace else { return }

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        contentContainer = container

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
        ])

        // --- Name row ---
        let nameLabel = NSTextField(labelWithString: "Name:")
        nameLabel.alignment = .right
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        nameField = NSTextField()
        nameField.stringValue = workspace.name
        nameField.placeholderString = "Workspace name"
        nameField.delegate = self
        nameField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameField)

        // --- Icon row ---
        let iconLabel = NSTextField(labelWithString: "Icon:")
        iconLabel.alignment = .right
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconLabel)

        iconButton = NSButton()
        iconButton.bezelStyle = .regularSquare
        iconButton.target = self
        iconButton.action = #selector(pickIcon)
        iconButton.translatesAutoresizingMaskIntoConstraints = false
        updateIconButton()
        container.addSubview(iconButton)

        let iconHint = NSTextField(labelWithString: "Click to choose")
        iconHint.font = .systemFont(ofSize: 11)
        iconHint.textColor = .secondaryLabelColor
        iconHint.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconHint)

        // --- Accounts section ---
        let accountsHeader = sectionHeader("ACCOUNTS")
        container.addSubview(accountsHeader)

        accountsTableView = NSTableView()
        accountsTableView.rowHeight = 26
        accountsTableView.usesAlternatingRowBackgroundColors = true
        accountsTableView.dataSource = self
        accountsTableView.delegate = self

        let typeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeCol.title = "Type"
        typeCol.width = 100
        let acctCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("account"))
        acctCol.title = "Account"
        accountsTableView.addTableColumn(typeCol)
        accountsTableView.addTableColumn(acctCol)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = accountsTableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .bezelBorder
        container.addSubview(scrollView)

        // Account buttons row
        let addAccountBtn = NSButton(title: "+ Add Account", target: self, action: #selector(addAccount))
        addAccountBtn.bezelStyle = .rounded
        addAccountBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(addAccountBtn)

        let removeAccountBtn = NSButton(title: "Remove", target: self, action: #selector(removeAccount))
        removeAccountBtn.bezelStyle = .rounded
        removeAccountBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(removeAccountBtn)

        // --- Discovery section ---
        let discoveryHeader = sectionHeader("DISCOVERY")
        container.addSubview(discoveryHeader)

        claudeLoginBtn = NSButton(title: "Login with Claude", target: self, action: #selector(loginWithClaude))
        claudeLoginBtn.bezelStyle = .rounded
        claudeLoginBtn.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
        claudeLoginBtn.imagePosition = .imageLeading
        claudeLoginBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(claudeLoginBtn)

        githubLoginBtn = NSButton(title: "Login with GitHub", target: self, action: #selector(loginWithGitHub))
        githubLoginBtn.bezelStyle = .rounded
        githubLoginBtn.image = NSImage(systemSymbolName: "person.badge.key", accessibilityDescription: nil)
        githubLoginBtn.imagePosition = .imageLeading
        githubLoginBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(githubLoginBtn)

        // --- Layout ---
        NSLayoutConstraint.activate([
            // Name
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            nameLabel.widthAnchor.constraint(equalToConstant: 50),

            nameField.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            nameField.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            nameField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            nameField.heightAnchor.constraint(equalToConstant: 22),

            // Icon
            iconLabel.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 14),
            iconLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 50),

            iconButton.centerYAnchor.constraint(equalTo: iconLabel.centerYAnchor),
            iconButton.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            iconButton.widthAnchor.constraint(equalToConstant: 40),
            iconButton.heightAnchor.constraint(equalToConstant: 40),

            iconHint.centerYAnchor.constraint(equalTo: iconButton.centerYAnchor),
            iconHint.leadingAnchor.constraint(equalTo: iconButton.trailingAnchor, constant: 8),

            // Accounts header
            accountsHeader.topAnchor.constraint(equalTo: iconButton.bottomAnchor, constant: 20),
            accountsHeader.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            accountsHeader.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            // Table - flex height between header and buttons below
            scrollView.topAnchor.constraint(equalTo: accountsHeader.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),

            // Account buttons
            addAccountBtn.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            addAccountBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            removeAccountBtn.centerYAnchor.constraint(equalTo: addAccountBtn.centerYAnchor),
            removeAccountBtn.leadingAnchor.constraint(equalTo: addAccountBtn.trailingAnchor, constant: 8),

            // Discovery header
            discoveryHeader.topAnchor.constraint(equalTo: addAccountBtn.bottomAnchor, constant: 20),
            discoveryHeader.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            discoveryHeader.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            // Discover buttons
            claudeLoginBtn.topAnchor.constraint(equalTo: discoveryHeader.bottomAnchor, constant: 8),
            claudeLoginBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            githubLoginBtn.centerYAnchor.constraint(equalTo: claudeLoginBtn.centerYAnchor),
            githubLoginBtn.leadingAnchor.constraint(equalTo: claudeLoginBtn.trailingAnchor, constant: 8),

            // Pin discovery to bottom
            claudeLoginBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    private func sectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func updateIconButton() {
        guard let workspace else { return }
        switch workspace.icon {
        case .emoji:
            iconButton.title = workspace.icon.displayString
            iconButton.image = nil
            iconButton.font = .systemFont(ofSize: 22)
        case .sfSymbol(let name):
            iconButton.title = ""
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            iconButton.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
            iconButton.imagePosition = .imageOnly
            iconButton.contentTintColor = .labelColor
        }
    }

    // MARK: - Actions

    @objc private func pickIcon() {
        let picker = IconPickerViewController()
        picker.onIconSelected = { [weak self] icon in
            guard let self else { return }
            self.workspace?.icon = icon
            self.updateIconButton()
            self.commit()
        }

        let popover = NSPopover()
        popover.contentViewController = picker
        popover.contentSize = NSSize(width: 320, height: 380)
        popover.behavior = .transient
        picker.popover = popover
        popover.show(relativeTo: iconButton.bounds, of: iconButton, preferredEdge: .maxX)
    }

    @objc private func addAccount() {
        guard let workspace else { return }
        let sheet = AddAccountSheetController(workspace: workspace) { [weak self] account in
            guard let self else { return }
            self.workspace?.accounts.append(account)
            self.accountsTableView.reloadData()
            self.commit()
            self.sheetController = nil
        }
        sheetController = sheet  // retain!
        view.window?.beginSheet(sheet.window!) { [weak self] _ in
            self?.sheetController = nil
        }
    }

    @objc private func removeAccount() {
        let row = accountsTableView.selectedRow
        guard row >= 0, row < (workspace?.accounts.count ?? 0) else { return }
        workspace?.accounts.remove(at: row)
        accountsTableView.reloadData()
        commit()
    }

    @objc private func loginWithClaude() {
        guard workspace != nil else { return }

        // If already logging in, cancel
        if activeLoginProcess != nil {
            cancelActiveLogin(claudeLoginBtn)
            return
        }

        do {
            activeLoginProcess = try ClaudeCodeSwitcher.startLogin()
        } catch {
            alert("Login failed", info: error.localizedDescription)
            return
        }

        setLoginButton(claudeLoginBtn, loading: true)

        Task {
            do {
                try await activeLoginProcess!.waitForExit()
                let discovered = ClaudeCodeSwitcher.discoverAccounts()
                await MainActor.run {
                    self.activeLoginProcess = nil
                    self.setLoginButton(self.claudeLoginBtn, loading: false)
                    guard let account = discovered.first else {
                        self.alert("Login succeeded", info: "No account found in Keychain. Try again.")
                        return
                    }
                    self.saveDiscoveredAccount(account)
                }
            } catch {
                await MainActor.run {
                    self.activeLoginProcess = nil
                    self.setLoginButton(self.claudeLoginBtn, loading: false)
                    // Don't show error if user cancelled
                    if (error as? ShellError) != nil {
                        let shellErr = error as! ShellError
                        if case .nonZeroExit(let code, _) = shellErr, code == 15 || code == -1 { return }
                    }
                    self.alert("Login failed", info: error.localizedDescription)
                }
            }
        }
    }

    private func saveDiscoveredAccount(_ account: ClaudeCodeSwitcher.DiscoveredAccount) {
        let lbl = account.keychainItem.label ?? account.keychainItem.account
        // Update snapshot if account already exists
        for (i, acc) in workspace!.accounts.enumerated() {
            if case .claudeCode(var payload) = acc.payload,
               payload.keychainAccount == account.keychainItem.account {
                payload.tokenSnapshot = account.tokenData
                payload.label = lbl
                workspace!.accounts[i].payload = .claudeCode(payload)
                workspace!.accounts[i].displayName = lbl
                accountsTableView.reloadData()
                commit()
                alert("Account updated", info: "\(lbl) credentials refreshed.")
                return
            }
        }
        // New account
        workspace!.accounts.append(Account(
            displayName: lbl,
            payload: .claudeCode(ClaudeCodePayload(
                keychainAccount: account.keychainItem.account,
                label: lbl,
                tokenSnapshot: account.tokenData
            ))
        ))
        accountsTableView.reloadData()
        commit()
        alert("Account added", info: "\(lbl) added to this workspace.")
    }

    @objc private func loginWithGitHub() {
        guard workspace != nil else { return }

        // If already logging in, cancel
        if activeLoginProcess != nil {
            cancelActiveLogin(githubLoginBtn)
            return
        }

        do {
            activeLoginProcess = try GitHubSwitcher.startLogin()
        } catch {
            alert("Login failed", info: error.localizedDescription)
            return
        }

        setLoginButton(githubLoginBtn, loading: true)

        Task {
            do {
                try await activeLoginProcess!.waitForExit()
                let accounts = try GitHubSwitcher.listAccounts()
                await MainActor.run {
                    self.activeLoginProcess = nil
                    self.setLoginButton(self.githubLoginBtn, loading: false)
                    guard !accounts.isEmpty else {
                        self.alert("Login succeeded", info: "No accounts found via gh CLI.")
                        return
                    }
                    self.saveDiscoveredGitHubAccounts(accounts)
                }
            } catch {
                await MainActor.run {
                    self.activeLoginProcess = nil
                    self.setLoginButton(self.githubLoginBtn, loading: false)
                    if (error as? ShellError) != nil {
                        let shellErr = error as! ShellError
                        if case .nonZeroExit(let code, _) = shellErr, code == 15 || code == -1 { return }
                    }
                    self.alert("GitHub login failed", info: error.localizedDescription)
                }
            }
        }
    }

    private func saveDiscoveredGitHubAccounts(_ accounts: [(username: String, hostname: String)]) {
        let existing = Set(workspace!.accounts.compactMap {
            if case .gitHub(let p) = $0.payload { return "\(p.username)@\(p.hostname)" } else { return nil }
        })
        var added = 0
        for (username, hostname) in accounts {
            guard !existing.contains("\(username)@\(hostname)") else { continue }
            workspace!.accounts.append(Account(
                displayName: "\(username) (\(hostname))",
                payload: .gitHub(GitHubPayload(username: username, hostname: hostname))
            ))
            added += 1
        }
        accountsTableView.reloadData()
        commit()
        alert("GitHub account added", info: added > 0 ? "Added \(added) account(s)." : "Account already exists in this workspace.")
    }

    private static let spinnerIdentifier = NSUserInterfaceItemIdentifier("loginSpinner")

    private func setLoginButton(_ button: NSButton, loading: Bool) {
        if loading {
            button.title = "Cancel"
            button.isEnabled = true
            button.contentTintColor = .systemRed

            let spinner = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 14, height: 14))
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.startAnimation(nil)
            spinner.identifier = Self.spinnerIdentifier
            button.addSubview(spinner)
            spinner.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                spinner.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -8),
                spinner.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            ])
        } else {
            button.isEnabled = true
            button.title = button === claudeLoginBtn ? "Login with Claude" : "Login with GitHub"
            button.contentTintColor = nil
            button.subviews.first { $0.identifier == Self.spinnerIdentifier }?.removeFromSuperview()
        }
    }

    private func cancelActiveLogin(_ button: NSButton) {
        activeLoginProcess?.cancel()
        activeLoginProcess = nil
        setLoginButton(button, loading: false)
    }

    private func alert(_ title: String, info: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = info
        a.runModal()
    }

    private func commit() {
        guard let workspace else { return }
        store.updateWorkspace(workspace)
        onWorkspaceUpdated?()
    }
}

// MARK: - Name field delegate

extension WorkspaceDetailViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === nameField else { return }
        workspace?.name = field.stringValue
        commit()
    }
}

// MARK: - Accounts table

extension WorkspaceDetailViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        workspace?.accounts.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let account = workspace?.accounts[row] else { return nil }
        let id = tableColumn?.identifier
        let text: String
        if id?.rawValue == "type" {
            text = account.type == .claudeCode ? "Claude Code" : "GitHub"
        } else {
            text = account.displayName
        }

        var cell = tableView.makeView(withIdentifier: accountCellID, owner: self) as? NSTableCellView
        if cell == nil {
            let c = NSTableCellView()
            c.identifier = accountCellID
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            c.addSubview(tf)
            c.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            ])
            cell = c
        }
        cell?.textField?.stringValue = text
        return cell
    }
}
