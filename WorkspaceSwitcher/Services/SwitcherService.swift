import Foundation
import AppKit

/// Orchestrates switching all accounts in a workspace.
struct SwitcherService {

    /// Switches to all accounts in the given workspace.
    /// Returns a list of errors (empty = full success).
    @discardableResult
    static func switchTo(workspace: Workspace) async -> [SwitchError] {
        var errors: [SwitchError] = []

        for account in workspace.accounts {
            do {
                switch account.payload {
                case .claudeCode(let payload):
                    guard let tokenData = payload.tokenSnapshot else {
                        throw NSError(domain: "SwitcherService", code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: "No token snapshot saved for \(payload.label). Re-discover this account."])
                    }
                    try ClaudeCodeSwitcher.switchTo(account: payload.keychainAccount, tokenData: tokenData)

                case .gitHub(let payload):
                    try GitHubSwitcher.switchTo(username: payload.username, hostname: payload.hostname)
                }
            } catch {
                errors.append(SwitchError(accountName: account.displayName, underlying: error))
            }
        }

        return errors
    }

    /// Convenience: switch and post user notification on errors.
    /// If Claude sessions are running, prompts the user to terminate them first.
    static func switchAndNotify(workspace: Workspace, store: WorkspaceStore) {
        let hasClaude = workspace.accounts.contains { $0.type == .claudeCode }

        if hasClaude {
            let sessions = ClaudeCodeSwitcher.runningSessions()
            if !sessions.isEmpty {
                let proceed = promptToTerminateSessions(sessions, workspace: workspace.name)
                guard proceed else { return }
            }
        }

        Task {
            let errors = await switchTo(workspace: workspace)
            await MainActor.run {
                if errors.isEmpty {
                    store.setActiveWorkspace(id: workspace.id)
                }
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                if errors.isEmpty {
                    alert.messageText = "Switched to \(workspace.name)"
                    alert.informativeText = "Claude Code credentials updated successfully."
                    alert.alertStyle = .informational
                } else {
                    alert.messageText = "Switch failed"
                    alert.alertStyle = .critical
                    let details = errors.map { "• \($0.accountName): \($0.underlying.localizedDescription)" }.joined(separator: "\n")
                    alert.informativeText = details
                }
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    // MARK: - Session prompt

    /// Shows an alert listing running Claude sessions and asks whether to terminate them.
    /// Returns true if the user confirmed (sessions terminated) or chose to continue anyway.
    private static func promptToTerminateSessions(
        _ sessions: [ClaudeCodeSwitcher.RunningSession],
        workspace: String
    ) -> Bool {
        // Bring app to front so the alert is visible (menu bar apps are .accessory by default)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Active Claude Code sessions detected"
        alert.alertStyle = .warning

        let sessionList = sessions.map { session in
            let dir = (session.cwd as NSString).lastPathComponent
            return "  PID \(session.pid) — \(dir)"
        }.joined(separator: "\n")

        alert.informativeText = """
        Switching to "\(workspace)" will change the Claude Code credentials. \
        These running sessions still use the previous account and could overwrite the new credentials when they refresh their token:

        \(sessionList)

        Terminate them now? You can resume each session afterwards with `claude --resume`.
        """

        alert.addButton(withTitle: "Terminate & Switch")
        alert.addButton(withTitle: "Switch Anyway")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            // Terminate sessions gracefully (SIGINT) and wait for them to exit
            ClaudeCodeSwitcher.terminateSessions(sessions)
            waitForProcesses(sessions.map { Int32($0.pid) }, timeout: 3.0)
            return true
        case .alertSecondButtonReturn:
            // Continue without terminating
            return true
        default:
            // Cancel
            return false
        }
    }

    // MARK: - Process waiting

    /// Waits up to `timeout` seconds for all given PIDs to exit.
    private static func waitForProcesses(_ pids: [Int32], timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let alive = pids.filter { kill($0, 0) == 0 }
            if alive.isEmpty { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

}

struct SwitchError: Error {
    var accountName: String
    var underlying: Error
}
