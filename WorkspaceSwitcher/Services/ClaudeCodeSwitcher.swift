import Foundation

/// Manages Claude Code CLI account switching via Keychain credential backup/restore.
///
/// Claude CLI stores a single OAuth credential in the macOS Keychain under
/// service "Claude Code-credentials". The ACL on that item only authorizes
/// /usr/bin/security for decrypt — so we use the `security` CLI for both
/// reads (discovery) and writes (switching) to avoid ACL dialogs.
///
/// Discovery flow:
///   1. Run `security find-generic-password -s "Claude Code-credentials"` to get account name
///   2. Run `security find-generic-password -s "Claude Code-credentials" -w` to get token data
///   3. Store both in workspaces.json as tokenSnapshot
///
/// Switch flow:
///   1. Run `security add-generic-password -U -s "Claude Code-credentials" -a <acct> -w <json>`
///   2. Claude CLI reads Keychain on next invocation and picks up the new credential
struct ClaudeCodeSwitcher {

    private static let keychainService = "Claude Code-credentials"
    private static let securityPath = "/usr/bin/security"

    private static let claudeCandidatePaths = [
        "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/claude",
        "/usr/local/bin/claude",
        "/opt/homebrew/bin/claude",
        "/usr/bin/claude"
    ]

    /// Resolves the `claude` binary path.
    static func claudePath() -> String? {
        if let known = claudeCandidatePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return known
        }
        // Use an interactive login shell to resolve PATH (picks up nvm, homebrew, etc.)
        if let found = try? Shell.run("/bin/zsh", args: ["-ilc", "which claude"]), !found.isEmpty {
            return found
        }
        return nil
    }

    /// Launches `claude auth login` and returns a cancellable handle.
    static func startLogin() throws -> CancellableProcess {
        guard let claude = claudePath() else {
            throw ClaudeCodeError.claudeNotFound
        }
        return try Shell.launchCancellable(claude, args: ["auth", "login"])
    }

    /// A discovered Claude Code account with its token data.
    struct DiscoveredAccount {
        var keychainItem: KeychainItem
        var tokenData: Data
    }

    // MARK: - Discovery

    /// Returns the current Claude Code account from Keychain, including token data.
    /// Uses /usr/bin/security which has ACL access to the item.
    static func discoverAccounts() -> [DiscoveredAccount] {
        // Get account name (attributes only, no ACL needed)
        let items = KeychainService.listItems(service: keychainService)
        guard !items.isEmpty else { return [] }

        // Read token data via security CLI (authorized in ACL)
        guard let jsonString = try? Shell.run(securityPath, args: [
            "find-generic-password",
            "-s", keychainService,
            "-w"   // print password to stdout
        ]), let tokenData = jsonString.data(using: .utf8) else {
            return []
        }

        return items.map { item in
            DiscoveredAccount(keychainItem: item, tokenData: tokenData)
        }
    }

    // MARK: - Switching

    /// Activates the given Claude Code account by writing its token into the Keychain.
    /// Uses /usr/bin/security CLI to bypass ACL restrictions on the item.
    ///
    /// Important: We must delete ALL existing items for the service first, then add
    /// the new one. Using `-U` alone only matches by service+account, so switching
    /// from accountA to accountB would leave accountA's item in place and add a
    /// second item — Claude CLI then reads whichever comes first (the old one).
    static func switchTo(account keychainAccount: String, tokenData: Data) throws {
        guard let jsonString = String(data: tokenData, encoding: .utf8) else {
            throw ClaudeCodeError.invalidTokenData
        }
        // Remove all existing credentials for this service so Claude CLI
        // doesn't pick up a stale item from a different account.
        let existingItems = KeychainService.listItems(service: keychainService)
        for item in existingItems {
            try? Shell.run(securityPath, args: [
                "delete-generic-password",
                "-s", keychainService,
                "-a", item.account
            ])
        }
        // Add the new credential
        try Shell.run(securityPath, args: [
            "add-generic-password",
            "-s", keychainService,
            "-a", keychainAccount,
            "-w", jsonString
        ])
    }

    /// Returns the currently active account identifier from Keychain, if any.
    static func activeAccount() -> String? {
        KeychainService.listItems(service: keychainService).first?.account
    }

    // MARK: - Session management

    /// Info about a running Claude CLI session.
    struct RunningSession {
        var pid: Int
        var sessionId: String
        var cwd: String
    }

    /// Returns currently running Claude CLI sessions by scanning ~/.claude/sessions/.
    static func runningSessions() -> [RunningSession] {
        let sessionsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/sessions")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: sessionsDir, includingPropertiesForKeys: nil
        ) else { return [] }

        return files.compactMap { url -> RunningSession? in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pid = json["pid"] as? Int,
                  let sessionId = json["sessionId"] as? String,
                  let cwd = json["cwd"] as? String else { return nil }
            // Check if process is still alive
            guard kill(Int32(pid), 0) == 0 else { return nil }
            return RunningSession(pid: pid, sessionId: sessionId, cwd: cwd)
        }
    }

    /// Terminates the given Claude CLI sessions gracefully (SIGINT, like Ctrl+C).
    /// Using SIGINT allows Claude's TUI to clean up properly and persist session state for resume.
    static func terminateSessions(_ sessions: [RunningSession]) {
        for session in sessions {
            kill(Int32(session.pid), SIGINT)
        }
    }
}

enum ClaudeCodeError: Error, LocalizedError {
    case invalidTokenData
    case claudeNotFound

    var errorDescription: String? {
        switch self {
        case .invalidTokenData: return "Token data is not valid UTF-8 JSON"
        case .claudeNotFound: return "Claude CLI not found. Install it from claude.ai/code"
        }
    }
}
