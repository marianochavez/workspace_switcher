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
        if let found = try? Shell.run("/bin/zsh", args: ["-ilc", "which gh"]), !found.isEmpty {
            return found
        }
        return nil
    }

    /// Launches `gh auth login --web` and returns a cancellable handle.
    /// Parses stderr for the one-time device code and calls `onDeviceCode` on the main thread.
    /// The caller is responsible for opening the browser after showing the code to the user.
    static func startLogin(hostname: String = "github.com",
                           onDeviceCode: @escaping (String) -> Void) throws -> CancellableProcess {
        guard let gh = ghPath() else {
            throw GitHubError.ghNotFound
        }

        let process = try Shell.launchCancellable(gh, args: [
            "auth", "login",
            "--web",
            "--hostname", hostname,
            "--git-protocol", "https",
            "--skip-ssh-key"
        ])

        var codeFound = false
        process.observeStderr { text in
            guard !codeFound else { return }
            // gh outputs: "! First copy your one-time code: XXXX-XXXX"
            if let code = Self.parseDeviceCode(from: text) {
                codeFound = true
                DispatchQueue.main.async {
                    onDeviceCode(code)
                }
            }
        }

        return process
    }

    /// Extracts the device code from gh CLI output.
    /// Matches patterns like "code: XXXX-XXXX" or standalone "XXXX-XXXX".
    static func parseDeviceCode(from text: String) -> String? {
        // Pattern: "code: XXXX-XXXX"
        if let range = text.range(of: #"code:\s*([A-Z0-9]{4}-[A-Z0-9]{4})"#, options: .regularExpression) {
            let match = String(text[range])
            return match.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces)
        }
        // Fallback: standalone XXXX-XXXX pattern
        if let range = text.range(of: #"[A-Z0-9]{4}-[A-Z0-9]{4}"#, options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }

    /// The device verification URL for the given hostname.
    static func deviceURL(hostname: String = "github.com") -> URL {
        if hostname == "github.com" {
            return URL(string: "https://github.com/login/device")!
        }
        return URL(string: "https://\(hostname)/login/device")!
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

    /// Returns the currently active GitHub account (the one most recently authenticated).
    static func activeAccount() throws -> (username: String, hostname: String)? {
        guard let gh = ghPath() else {
            throw GitHubError.ghNotFound
        }
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

        return parseActiveAccount(combined)
    }

    static func parseAuthStatus(_ output: String) -> [(username: String, hostname: String)] {
        var results: [(String, String)] = []

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Account lines: "✓ Logged in to github.com account <username> (...)"
            if trimmed.contains("Logged in to") {
                let parts = trimmed.components(separatedBy: " ")
                if let accountIdx = parts.firstIndex(of: "account"), accountIdx + 1 < parts.count {
                    let username = parts[accountIdx + 1]
                    if let toIdx = parts.firstIndex(of: "to"), toIdx + 1 < parts.count {
                        let host = parts[toIdx + 1]
                        results.append((username, host))
                    }
                }
            }
        }
        return results
    }

    /// Parses gh auth status output to find the active account.
    /// Looks for "Logged in to" followed by "Active account: true".
    static func parseActiveAccount(_ output: String) -> (username: String, hostname: String)? {
        let lines = output.components(separatedBy: .newlines)
        var lastAccount: (String, String)?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("Logged in to") {
                let parts = trimmed.components(separatedBy: " ")
                if let accountIdx = parts.firstIndex(of: "account"), accountIdx + 1 < parts.count,
                   let toIdx = parts.firstIndex(of: "to"), toIdx + 1 < parts.count {
                    lastAccount = (parts[accountIdx + 1], parts[toIdx + 1])
                }
            }

            if trimmed.contains("Active account: true"), let account = lastAccount {
                return account
            }

            // Reset if we hit the next account block
            if trimmed.contains("Active account: false") {
                lastAccount = nil
            }
        }
        return lastAccount
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
