import SwiftUI
import ServiceManagement

// MARK: - Main Settings View

struct SettingsContentView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var selectedWorkspaceID: UUID?

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, selection: $selectedWorkspaceID)
        } detail: {
            if let id = selectedWorkspaceID,
               store.workspaces.contains(where: { $0.id == id }) {
                WorkspaceDetailView(store: store, workspaceID: id)
                    .id(id)
            } else {
                Text("Select or add a workspace")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Sidebar

private struct SidebarView: View {
    @ObservedObject var store: WorkspaceStore
    @Binding var selection: UUID?
    @State private var showDeleteAlert = false

    var body: some View {
        List(selection: $selection) {
            ForEach(store.workspaces) { workspace in
                Label {
                    Text(workspace.name)
                } icon: {
                    WorkspaceIconView(icon: workspace.icon, size: 16)
                }
                .tag(workspace.id)
            }
        }
        .listStyle(.sidebar)
        .onAppear { refreshLaunchAtLogin() }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                Divider()
            }
        }
        .alert("Launch at Login", isPresented: $showLaunchAtLoginError) {
            Button("OK") {}
        } message: {
            Text(launchAtLoginErrorMessage)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 0) {
                    Button(action: addWorkspace) {
                        Image(systemName: "plus")
                            .frame(width: 28, height: 24)
                    }
                    .buttonStyle(.borderless)

                    Button(action: { showDeleteAlert = true }) {
                        Image(systemName: "minus")
                            .frame(width: 28, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .disabled(selection == nil)

                    Spacer()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
        }
        .alert("Delete workspace?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { removeWorkspace() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let id = selection, let ws = store.workspaces.first(where: { $0.id == id }) {
                Text("This will remove \"\(ws.name)\" and all its account associations.")
            }
        }
    }

    private func addWorkspace() {
        let ws = Workspace(name: "New Workspace")
        store.addWorkspace(ws)
        selection = ws.id
    }

    private func removeWorkspace() {
        guard let id = selection else { return }
        store.deleteWorkspace(id: id)
        selection = nil
    }

    @State private var launchAtLogin = false
    @State private var showLaunchAtLoginError = false
    @State private var launchAtLoginErrorMessage = ""

    private func refreshLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                guard #available(macOS 13.0, *) else { return }
                do {
                    if newValue { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                    launchAtLogin = newValue
                } catch {
                    report(error)
                    launchAtLoginErrorMessage = error.localizedDescription
                    showLaunchAtLoginError = true
                    // Revert the toggle
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
        )
    }
}

// MARK: - Workspace Detail

private struct WorkspaceDetailView: View {
    @ObservedObject var store: WorkspaceStore
    let workspaceID: UUID

    @State private var name: String = ""
    @State private var showIconPicker = false
    @State private var activeProcess: CancellableProcess?
    @State private var loginType: AccountType?
    @State private var deviceCode: String?
    @State private var showDeviceCodeAlert = false

    private var workspace: Workspace {
        store.workspaces.first { $0.id == workspaceID } ?? Workspace(name: "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Name & Icon
                nameAndIconSection
                    .padding(.bottom, 24)

                // Accounts
                accountsSection
                    .padding(.bottom, 24)

                // Add Accounts
                addAccountsSection
            }
            .padding(24)
        }
        .onAppear { name = workspace.name }
        .onDisappear { cancelLogin() }
        .alert("GitHub Device Code", isPresented: $showDeviceCodeAlert) {
            Button("Open GitHub") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(deviceCode ?? "", forType: .string)
                NSWorkspace.shared.open(GitHubSwitcher.deviceURL())
            }
            Button("Cancel", role: .cancel) {
                cancelLogin()
            }
        } message: {
            Text("Your one-time code has been copied to the clipboard:\n\n\(deviceCode ?? "")\n\nPaste this code on GitHub to complete authentication.")
        }
    }

    // MARK: - Name & Icon

    private var nameAndIconSection: some View {
        HStack(spacing: 16) {
            // Icon button
            Button(action: { showIconPicker.toggle() }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .frame(width: 56, height: 56)
                    WorkspaceIconView(icon: workspace.icon, size: 28)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showIconPicker) {
                IconPickerView { icon in
                    var ws = workspace
                    ws.icon = icon
                    store.updateWorkspace(ws)
                    showIconPicker = false
                }
                .frame(width: 320, height: 380)
            }

            // Name field
            VStack(alignment: .leading, spacing: 4) {
                Text("WORKSPACE NAME")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Workspace name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: name) { _ in
                        var ws = workspace
                        ws.name = name
                        store.updateWorkspace(ws)
                    }
            }
        }
    }

    // MARK: - Accounts

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACCOUNTS")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            if workspace.accounts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text("No accounts yet")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text("Use the buttons below to add accounts")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
            } else {
                VStack(spacing: 1) {
                    ForEach(workspace.accounts) { account in
                        AccountRow(account: account) {
                            removeAccount(account)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Add Accounts

    private var githubAccountCount: Int {
        workspace.accounts.filter { $0.type == .gitHub }.count
    }

    private var claudeAccountCount: Int {
        workspace.accounts.filter { $0.type == .claudeCode }.count
    }

    private var addAccountsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ADD ACCOUNTS")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                LoginCard(
                    title: "GitHub",
                    subtitle: githubAccountCount > 0
                        ? "\(githubAccountCount) added — Add another"
                        : "Login with gh CLI",
                    iconName: "chevron.left.forwardslash.chevron.right",
                    color: .primary,
                    isLoading: loginType == .gitHub,
                    hasAccounts: githubAccountCount > 0,
                    action: loginType == .gitHub ? cancelLogin : loginWithGitHub
                )

                LoginCard(
                    title: "Claude Code",
                    subtitle: claudeAccountCount > 0
                        ? "\(claudeAccountCount) added — Add another"
                        : "Login with Claude CLI",
                    iconName: "terminal.fill",
                    color: .orange,
                    isLoading: loginType == .claudeCode,
                    hasAccounts: claudeAccountCount > 0,
                    action: loginType == .claudeCode ? cancelLogin : loginWithClaude
                )
            }
        }
    }

    // MARK: - Actions

    private func removeAccount(_ account: Account) {
        var ws = workspace
        ws.accounts.removeAll { $0.id == account.id }
        store.updateWorkspace(ws)
    }

    private func loginWithGitHub() {
        do {
            activeProcess = try GitHubSwitcher.startLogin { [self] code in
                deviceCode = code
                showDeviceCodeAlert = true
            }
            loginType = .gitHub
        } catch {
            report(error)
            showErrorAlert("Login failed", message: error.localizedDescription)
            return
        }

        Task {
            do {
                try await activeProcess?.waitForExit()
                // Get only the active account (the one just authenticated)
                let active = try GitHubSwitcher.activeAccount()
                await MainActor.run {
                    loginType = nil
                    activeProcess = nil
                    guard let active else {
                        showInfoAlert("GitHub", message: "No account was found after login.")
                        return
                    }
                    saveDiscoveredGitHubAccount(active)
                }
            } catch {
                await MainActor.run {
                    let wasCancelled = isCancellationError(error)
                    loginType = nil
                    activeProcess = nil
                    if !wasCancelled {
                        report(error)
                        showErrorAlert("GitHub login failed", message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func loginWithClaude() {
        do {
            activeProcess = try ClaudeCodeSwitcher.startLogin()
            loginType = .claudeCode
        } catch {
            report(error)
            showErrorAlert("Login failed", message: error.localizedDescription)
            return
        }

        Task {
            do {
                try await activeProcess?.waitForExit()
                let discovered = ClaudeCodeSwitcher.discoverAccounts()
                await MainActor.run {
                    loginType = nil
                    activeProcess = nil
                    if let account = discovered.first {
                        saveDiscoveredClaudeAccount(account)
                    }
                }
            } catch {
                await MainActor.run {
                    let wasCancelled = isCancellationError(error)
                    loginType = nil
                    activeProcess = nil
                    if !wasCancelled {
                        report(error)
                        showErrorAlert("Claude login failed", message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func cancelLogin() {
        activeProcess?.cancel()
        activeProcess = nil
        loginType = nil
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if let shellErr = error as? ShellError,
           case .nonZeroExit(let code, _) = shellErr,
           code == 15 || code == -1 {
            return true
        }
        return false
    }

    private func saveDiscoveredGitHubAccount(_ account: (username: String, hostname: String)) {
        var ws = workspace
        let key = "\(account.username)@\(account.hostname)"
        let alreadyExists = ws.accounts.contains {
            if case .gitHub(let p) = $0.payload { return "\(p.username)@\(p.hostname)" == key }
            return false
        }
        if alreadyExists {
            showInfoAlert("GitHub", message: "\(account.username) is already in this workspace.")
            return
        }
        ws.accounts.append(Account(
            displayName: "\(account.username) (\(account.hostname))",
            payload: .gitHub(GitHubPayload(username: account.username, hostname: account.hostname))
        ))
        store.updateWorkspace(ws)
        showInfoAlert("GitHub", message: "Added \(account.username).")
    }

    private func saveDiscoveredClaudeAccount(_ account: ClaudeCodeSwitcher.DiscoveredAccount) {
        var ws = workspace
        let lbl = account.keychainItem.label ?? account.keychainItem.account

        // Update existing
        for (i, acc) in ws.accounts.enumerated() {
            if case .claudeCode(var payload) = acc.payload,
               payload.keychainAccount == account.keychainItem.account {
                payload.tokenSnapshot = account.tokenData
                payload.oauthAccountSnapshot = account.oauthAccountData
                payload.label = lbl
                ws.accounts[i].payload = .claudeCode(payload)
                ws.accounts[i].displayName = lbl
                store.updateWorkspace(ws)
                showInfoAlert("Account updated", message: "\(lbl) credentials refreshed.")
                return
            }
        }

        // New account
        ws.accounts.append(Account(
            displayName: lbl,
            payload: .claudeCode(ClaudeCodePayload(
                keychainAccount: account.keychainItem.account,
                label: lbl,
                tokenSnapshot: account.tokenData,
                oauthAccountSnapshot: account.oauthAccountData
            ))
        ))
        store.updateWorkspace(ws)
        showInfoAlert("Account added", message: "\(lbl) added to this workspace.")
    }

    private func showErrorAlert(_ title: String, message: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.alertStyle = .warning
        a.runModal()
    }

    private func showInfoAlert(_ title: String, message: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.runModal()
    }
}

// MARK: - Account Row

private struct AccountRow: View {
    let account: Account
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Type badge
            ZStack {
                Circle()
                    .fill(badgeColor)
                    .frame(width: 32, height: 32)
                Image(systemName: badgeIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.system(size: 13, weight: .medium))
                Text(account.type == .gitHub ? "GitHub" : "Claude Code")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var badgeColor: Color {
        account.type == .gitHub ? Color(nsColor: .systemGray) : .orange
    }

    private var badgeIcon: String {
        account.type == .gitHub ? "chevron.left.forwardslash.chevron.right" : "terminal.fill"
    }
}

// MARK: - Login Card

private struct LoginCard: View {
    let title: String
    let subtitle: String
    let iconName: String
    let color: Color
    let isLoading: Bool
    var hasAccounts: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isLoading ? Color.red.opacity(0.15) :
                              hasAccounts ? Color.green.opacity(0.12) : color.opacity(0.12))
                        .frame(width: 44, height: 44)

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else if hasAccounts {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: iconName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(color)
                    }
                }

                VStack(spacing: 2) {
                    Text(isLoading ? "Cancel" : title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isLoading ? .red : .primary)
                    if !isLoading {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(hasAccounts ? .green : .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isLoading ? Color.red.opacity(0.3) :
                            hasAccounts ? Color.green.opacity(0.3) : Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workspace Icon View

struct WorkspaceIconView: View {
    let icon: WorkspaceIcon
    let size: CGFloat

    var body: some View {
        switch icon {
        case .emoji(let e):
            Text(e)
                .font(.system(size: size))
        case .sfSymbol(let name):
            Image(systemName: name)
                .font(.system(size: size))
        }
    }
}

// MARK: - Icon Picker

private struct IconPickerView: View {
    let onSelect: (WorkspaceIcon) -> Void

    @State private var tab = 0
    @State private var search = ""
    @State private var customInput = ""

    private let columns = Array(repeating: GridItem(.fixed(36), spacing: 2), count: 8)

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("", selection: $tab) {
                Label("Menu Bar", systemImage: "menubar.rectangle").tag(0)
                Label("Custom", systemImage: "face.smiling").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(10)

            // Description
            Text(tab == 0
                 ? "Monochrome icons for the macOS menu bar"
                 : "Colorful icons for your workspace")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 6)

            TextField("Search...", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 10)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredSections, id: \.title) { section in
                        Text(section.title.uppercased())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 10)
                            .padding(.top, 6)

                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(section.items, id: \.self) { item in
                                iconButton(for: item)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            HStack {
                Text("Custom:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Emoji or SF Symbol name", text: $customInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { submitCustom() }
            }
            .padding(10)
        }
    }

    @ViewBuilder
    private func iconButton(for item: String) -> some View {
        Button(action: { selectItem(item) }) {
            Group {
                if tab == 1 {
                    Text(item)
                        .font(.system(size: 20))
                } else {
                    // Menu bar preview: white icon on dark background
                    Image(systemName: item)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(tab == 0 ? Color(nsColor: .darkGray) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
    }

    private struct IconSection: Identifiable {
        let title: String
        let items: [String]
        var id: String { title }
    }

    // MARK: - Menu Bar Icons (monochrome SF Symbols that look native in macOS menu bar)

    private let menuBarSections: [IconSection] = [
        IconSection(title: "Workspaces", items: [
            "rectangle.on.rectangle",
            "square.on.square",
            "rectangle.stack",
            "square.stack",
            "sidebar.squares.left",
            "uiwindow.split.2x1",
            "rectangle.split.3x1",
            "square.grid.2x2",
            "rectangle.3.group",
            "square.stack.3d.up",
            "square.2.layers.3d",
            "square.3.layers.3d",
        ]),
        IconSection(title: "People & Accounts", items: [
            "person",
            "person.fill",
            "person.2",
            "person.2.fill",
            "person.crop.circle",
            "person.crop.circle.fill",
            "person.badge.key",
            "person.badge.shield.checkmark",
            "figure.stand",
            "figure.walk",
            "brain.head.profile",
            "shared.with.you",
        ]),
        IconSection(title: "Development", items: [
            "terminal",
            "terminal.fill",
            "chevron.left.forwardslash.chevron.right",
            "curlybraces",
            "hammer",
            "hammer.fill",
            "wrench.and.screwdriver",
            "wrench.and.screwdriver.fill",
            "gearshape",
            "gearshape.fill",
            "gearshape.2",
            "cpu",
            "cpu.fill",
            "memorychip",
            "memorychip.fill",
            "externaldrive",
            "externaldrive.fill",
            "server.rack",
            "network",
            "globe",
        ]),
        IconSection(title: "Shapes & Symbols", items: [
            "circle",
            "circle.fill",
            "square",
            "square.fill",
            "triangle",
            "triangle.fill",
            "diamond",
            "diamond.fill",
            "hexagon",
            "hexagon.fill",
            "seal",
            "seal.fill",
            "shield",
            "shield.fill",
            "star",
            "star.fill",
            "heart",
            "heart.fill",
            "bolt",
            "bolt.fill",
        ]),
        IconSection(title: "Status & Indicators", items: [
            "checkmark.circle",
            "checkmark.circle.fill",
            "xmark.circle",
            "exclamationmark.triangle",
            "bell",
            "bell.fill",
            "flag",
            "flag.fill",
            "tag",
            "tag.fill",
            "bookmark",
            "bookmark.fill",
            "pin",
            "pin.fill",
            "mappin",
            "location",
            "location.fill",
            "eye",
            "eye.fill",
            "lock",
            "lock.fill",
            "key",
            "key.fill",
        ]),
        IconSection(title: "Objects", items: [
            "house",
            "house.fill",
            "building.2",
            "building.2.fill",
            "briefcase",
            "briefcase.fill",
            "folder",
            "folder.fill",
            "tray",
            "tray.fill",
            "archivebox",
            "archivebox.fill",
            "doc",
            "doc.fill",
            "paperplane",
            "paperplane.fill",
            "envelope",
            "envelope.fill",
            "lightbulb",
            "lightbulb.fill",
        ]),
        IconSection(title: "Nature & Weather", items: [
            "flame",
            "flame.fill",
            "drop",
            "drop.fill",
            "snowflake",
            "leaf",
            "leaf.fill",
            "moon",
            "moon.fill",
            "sun.max",
            "sun.max.fill",
            "cloud",
            "cloud.fill",
            "sparkles",
            "wand.and.stars",
            "mountain.2",
            "mountain.2.fill",
            "water.waves",
        ]),
        IconSection(title: "Media & Devices", items: [
            "desktopcomputer",
            "laptopcomputer",
            "display",
            "iphone",
            "ipad",
            "keyboard",
            "headphones",
            "gamecontroller",
            "gamecontroller.fill",
            "music.note",
            "play.fill",
            "camera",
            "camera.fill",
            "photo",
            "photo.fill",
            "wifi",
            "antenna.radiowaves.left.and.right",
        ]),
    ]

    // MARK: - Custom Icons (colorful emojis)

    private let customSections: [IconSection] = [
        IconSection(title: "Work", items: [
            "💼", "📁", "🏢", "💻", "🖥", "⌨️", "📊", "📈",
            "💰", "🏦", "📋", "🗂", "📎", "✏️", "🖊", "📝",
        ]),
        IconSection(title: "Development", items: [
            "🐛", "🧑‍💻", "👨‍💻", "👩‍💻", "🤖", "🦾", "🧠", "💡",
            "⚡", "🔌", "🖲", "🕹", "📟", "💾", "📀", "🔮",
        ]),
        IconSection(title: "Tools", items: [
            "🔧", "⚙️", "🛠", "🔨", "🔩", "🔑", "🗝", "🔐",
            "🧰", "⛏", "🪛", "🪚", "🔬", "🧪", "🧲", "🪄",
        ]),
        IconSection(title: "Colors & Shapes", items: [
            "⭐", "🔴", "🟢", "🔵", "🟡", "🟣", "🟠", "⚫",
            "⬛", "🔶", "🔷", "💎", "🏷", "🔖", "📌", "🎯",
        ]),
        IconSection(title: "Fun", items: [
            "🚀", "🎨", "📦", "🎮", "🎧", "🎵", "🎬", "📸",
            "🏆", "🎪", "🎭", "🎲", "🃏", "🧩", "🎁", "🎈",
        ]),
        IconSection(title: "Nature", items: [
            "🌐", "🏠", "🌙", "☀️", "🌊", "🔥", "❄️", "🌿",
            "🌸", "🍀", "🌈", "⛅", "🌍", "🏔", "🌋", "🏝",
        ]),
        IconSection(title: "Animals", items: [
            "🐱", "🐶", "🦊", "🐻", "🐼", "🐨", "🦁", "🐯",
            "🦄", "🐝", "🦋", "🐙", "🦀", "🐳", "🦅", "🐲",
        ]),
        IconSection(title: "Food", items: [
            "☕", "🍵", "🧃", "🍺", "🍕", "🍔", "🌮", "🍣",
            "🍩", "🧁", "🍪", "🍫", "🍎", "🍋", "🥑", "🍄",
        ]),
    ]

    private var filteredSections: [IconSection] {
        let sections = tab == 0 ? menuBarSections : customSections
        guard !search.isEmpty else { return sections }
        let q = search.lowercased()
        return sections.compactMap { section in
            let filtered = section.items.filter { $0.lowercased().contains(q) }
            return filtered.isEmpty ? nil : IconSection(title: section.title, items: filtered)
        }
    }

    private func selectItem(_ item: String) {
        let icon: WorkspaceIcon = tab == 0 ? .sfSymbol(item) : .emoji(item)
        onSelect(icon)
    }

    private func submitCustom() {
        let val = customInput.trimmingCharacters(in: .whitespaces)
        guard !val.isEmpty else { return }
        let icon: WorkspaceIcon
        if val.unicodeScalars.contains(where: { $0.properties.isEmoji && !$0.properties.isASCIIHexDigit }) && !val.contains(".") {
            icon = .emoji(val)
        } else {
            icon = .sfSymbol(val)
        }
        onSelect(icon)
    }
}

// MARK: - Error reporting

private func report(_ error: Error) {
    NSLog("WorkspaceSwitcher error: %@", error.localizedDescription)
}
