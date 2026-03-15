import AppKit

final class AddAccountSheetController: NSWindowController {
    private let onAdd: (Account) -> Void
    private var workspace: Workspace

    private var typeSegment: NSSegmentedControl!
    private var githubFields: NSView!
    private var claudeFields: NSView!

    private var usernameField: NSTextField!
    private var hostnameField: NSTextField!
    private var keychainField: NSTextField!
    private var labelField: NSTextField!

    init(workspace: Workspace, onAdd: @escaping (Account) -> Void) {
        self.workspace = workspace
        self.onAdd = onAdd

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        win.title = "Add Account"
        super.init(window: win)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        guard let cv = window?.contentView else { return }

        // Type selector
        let typeLabel = NSTextField(labelWithString: "Type:")
        typeLabel.alignment = .right
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(typeLabel)

        typeSegment = NSSegmentedControl(labels: ["GitHub", "Claude Code"], trackingMode: .selectOne, target: self, action: #selector(typeChanged))
        typeSegment.selectedSegment = 0
        typeSegment.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(typeSegment)

        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(sep)

        // GitHub fields container
        githubFields = NSView()
        githubFields.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(githubFields)

        let userLabel = makeLabel("Username:")
        githubFields.addSubview(userLabel)
        usernameField = makeField(placeholder: "octocat")
        githubFields.addSubview(usernameField)

        let hostLabel = makeLabel("Hostname:")
        githubFields.addSubview(hostLabel)
        hostnameField = makeField(placeholder: "github.com")
        hostnameField.stringValue = "github.com"
        githubFields.addSubview(hostnameField)

        NSLayoutConstraint.activate([
            userLabel.topAnchor.constraint(equalTo: githubFields.topAnchor),
            userLabel.leadingAnchor.constraint(equalTo: githubFields.leadingAnchor),
            userLabel.widthAnchor.constraint(equalToConstant: 90),

            usernameField.centerYAnchor.constraint(equalTo: userLabel.centerYAnchor),
            usernameField.leadingAnchor.constraint(equalTo: userLabel.trailingAnchor, constant: 8),
            usernameField.trailingAnchor.constraint(equalTo: githubFields.trailingAnchor),
            usernameField.heightAnchor.constraint(equalToConstant: 22),

            hostLabel.topAnchor.constraint(equalTo: userLabel.bottomAnchor, constant: 12),
            hostLabel.leadingAnchor.constraint(equalTo: githubFields.leadingAnchor),
            hostLabel.widthAnchor.constraint(equalToConstant: 90),

            hostnameField.centerYAnchor.constraint(equalTo: hostLabel.centerYAnchor),
            hostnameField.leadingAnchor.constraint(equalTo: hostLabel.trailingAnchor, constant: 8),
            hostnameField.trailingAnchor.constraint(equalTo: githubFields.trailingAnchor),
            hostnameField.heightAnchor.constraint(equalToConstant: 22),

            hostLabel.bottomAnchor.constraint(equalTo: githubFields.bottomAnchor),
        ])

        // Claude fields container
        claudeFields = NSView()
        claudeFields.translatesAutoresizingMaskIntoConstraints = false
        claudeFields.isHidden = true
        cv.addSubview(claudeFields)

        let kcLabel = makeLabel("Keychain ID:")
        claudeFields.addSubview(kcLabel)
        keychainField = makeField(placeholder: "user@example.com")
        claudeFields.addSubview(keychainField)

        let dispLabel = makeLabel("Display name:")
        claudeFields.addSubview(dispLabel)
        labelField = makeField(placeholder: "Work Account")
        claudeFields.addSubview(labelField)

        NSLayoutConstraint.activate([
            kcLabel.topAnchor.constraint(equalTo: claudeFields.topAnchor),
            kcLabel.leadingAnchor.constraint(equalTo: claudeFields.leadingAnchor),
            kcLabel.widthAnchor.constraint(equalToConstant: 90),

            keychainField.centerYAnchor.constraint(equalTo: kcLabel.centerYAnchor),
            keychainField.leadingAnchor.constraint(equalTo: kcLabel.trailingAnchor, constant: 8),
            keychainField.trailingAnchor.constraint(equalTo: claudeFields.trailingAnchor),
            keychainField.heightAnchor.constraint(equalToConstant: 22),

            dispLabel.topAnchor.constraint(equalTo: kcLabel.bottomAnchor, constant: 12),
            dispLabel.leadingAnchor.constraint(equalTo: claudeFields.leadingAnchor),
            dispLabel.widthAnchor.constraint(equalToConstant: 90),

            labelField.centerYAnchor.constraint(equalTo: dispLabel.centerYAnchor),
            labelField.leadingAnchor.constraint(equalTo: dispLabel.trailingAnchor, constant: 8),
            labelField.trailingAnchor.constraint(equalTo: claudeFields.trailingAnchor),
            labelField.heightAnchor.constraint(equalToConstant: 22),

            dispLabel.bottomAnchor.constraint(equalTo: claudeFields.bottomAnchor),
        ])

        // Buttons
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(cancelBtn)

        let addBtn = NSButton(title: "Add", target: self, action: #selector(add))
        addBtn.bezelStyle = .rounded
        addBtn.keyEquivalent = "\r"
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(addBtn)

        // Main layout
        NSLayoutConstraint.activate([
            typeLabel.topAnchor.constraint(equalTo: cv.topAnchor, constant: 16),
            typeLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            typeLabel.widthAnchor.constraint(equalToConstant: 50),

            typeSegment.centerYAnchor.constraint(equalTo: typeLabel.centerYAnchor),
            typeSegment.leadingAnchor.constraint(equalTo: typeLabel.trailingAnchor, constant: 8),

            sep.topAnchor.constraint(equalTo: typeSegment.bottomAnchor, constant: 12),
            sep.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: cv.trailingAnchor),

            githubFields.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 16),
            githubFields.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            githubFields.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),

            claudeFields.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 16),
            claudeFields.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            claudeFields.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),

            addBtn.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
            addBtn.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16),

            cancelBtn.trailingAnchor.constraint(equalTo: addBtn.leadingAnchor, constant: -8),
            cancelBtn.centerYAnchor.constraint(equalTo: addBtn.centerYAnchor),
        ])
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.alignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func makeField(placeholder: String) -> NSTextField {
        let f = NSTextField()
        f.placeholderString = placeholder
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }

    // MARK: - Actions

    @objc private func typeChanged() {
        let isGH = typeSegment.selectedSegment == 0
        githubFields.isHidden = !isGH
        claudeFields.isHidden = isGH
    }

    @objc private func cancel() {
        window?.sheetParent?.endSheet(window!)
    }

    @objc private func add() {
        let account: Account
        if typeSegment.selectedSegment == 0 {
            let username = usernameField.stringValue.trimmingCharacters(in: .whitespaces)
            let hostname = hostnameField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !username.isEmpty else {
                highlightField(usernameField)
                return
            }
            account = Account(
                displayName: "\(username) (\(hostname.isEmpty ? "github.com" : hostname))",
                payload: .gitHub(GitHubPayload(username: username, hostname: hostname.isEmpty ? "github.com" : hostname))
            )
        } else {
            let keychainID = keychainField.stringValue.trimmingCharacters(in: .whitespaces)
            let lbl = labelField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !keychainID.isEmpty else {
                highlightField(keychainField)
                return
            }
            account = Account(
                displayName: lbl.isEmpty ? keychainID : lbl,
                payload: .claudeCode(ClaudeCodePayload(keychainAccount: keychainID, label: lbl.isEmpty ? keychainID : lbl))
            )
        }
        window?.sheetParent?.endSheet(window!)
        onAdd(account)
    }

    private func highlightField(_ field: NSTextField) {
        window?.makeFirstResponder(field)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            field.animator().alphaValue = 0.3
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                field.animator().alphaValue = 1.0
            }
        }
    }
}
