import Foundation
import AppKit

struct GitHubSwitcher {

    // MARK: - gh binary discovery

    private static let candidatePaths = [
        "/opt/homebrew/bin/gh",
        "/usr/local/bin/gh",
        "/usr/bin/gh"
    ]

    /// Resolves the `gh` binary path. Prefers Homebrew locations, then PATH lookup.
    static func ghPath() -> String? {
        // Check known locations first (avoids spawning a shell)
        if let known = candidatePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return known
        }
        // Fallback: ask the shell (works if user has a non-standard PATH)
        if let found = try? Shell.run("/usr/bin/env", args: ["which", "gh"]), !found.isEmpty {
            return found
        }
        return nil
    }

    /// Launches `gh auth login --web` and returns a cancellable handle.
    /// Uses `--clipboard` to copy the device code to the user's clipboard automatically.
    /// Opens the browser manually since `gh` skips it when not running in a TTY.
    static func startLogin(hostname: String = "github.com") throws -> CancellableProcess {
        guard let gh = ghPath() else {
            throw GitHubError.ghNotFound
        }

        // Open browser ourselves — gh won't do it without a TTY
        let deviceURL = hostname == "github.com"
            ? "https://github.com/login/device"
            : "https://\(hostname)/login/device"
        NSWorkspace.shared.open(URL(string: deviceURL)!)

        return try Shell.launchCancellable(gh, args: [
            "auth", "login",
            "--web",
            "--clipboard",
            "--hostname", hostname,
            "--git-protocol", "https",
            "--skip-ssh-key"
        ])
    }

    // MARK: - Switch

    /// Switches the active GitHub account for the given hostname.
    static func switchTo(username: String, hostname: String = "github.com") throws {
        guard let gh = ghPath() else {
            throw GitHubError.ghNotFound
        }
        try Shell.run(gh, args: ["auth", "switch", "--user", username, "--hostname", hostname])
    }

    // MARK: - Discovery

    /// Returns authenticated GitHub accounts via `gh auth status`.
    /// Each line of the form "  ✓ <hostname>: <username> (..." is parsed.
    static func listAccounts() throws -> [(username: String, hostname: String)] {
        guard let gh = ghPath() else {
            throw GitHubError.ghNotFound
        }
        // `gh auth status` exits 0 even if no accounts; output goes to stderr on some versions
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gh)
        process.arguments = ["auth", "status"]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        let combined = [stdout, stderr].map {
            String(data: $0.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        }.joined()

        return parseAuthStatus(combined)
    }

    // MARK: - Parsing

    static func parseAuthStatus(_ output: String) -> [(username: String, hostname: String)] {
        var results: [(String, String)] = []
        var currentHost: String?

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Hostname header lines look like "github.com" or "github.example.com"
            if !trimmed.hasPrefix("✓") && !trimmed.hasPrefix("X") && !trimmed.isEmpty
                && !trimmed.hasPrefix("Logged") && !trimmed.hasPrefix("Token")
                && !trimmed.hasPrefix("-") && trimmed.contains(".") {
                currentHost = trimmed
            }

            // Account lines: "✓ Logged in to github.com account <username> (...)"
            if trimmed.contains("Logged in to") {
                let parts = trimmed.components(separatedBy: " ")
                if let accountIdx = parts.firstIndex(of: "account"), accountIdx + 1 < parts.count {
                    let username = parts[accountIdx + 1]
                    // Extract hostname from "Logged in to <host> account ..."
                    if let toIdx = parts.firstIndex(of: "to"), toIdx + 1 < parts.count {
                        let host = parts[toIdx + 1]
                        results.append((username, host))
                        currentHost = nil
                    }
                }
            }

            _ = currentHost
        }
        return results
    }
}

enum GitHubError: Error, LocalizedError {
    case ghNotFound
    case switchFailed(String)

    var errorDescription: String? {
        switch self {
        case .ghNotFound:
            return "GitHub CLI (gh) not found. Install via: brew install gh"
        case .switchFailed(let msg):
            return "gh auth switch failed: \(msg)"
        }
    }
}
