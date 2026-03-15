import Foundation

enum ShellError: Error, LocalizedError {
    case commandNotFound(String)
    case nonZeroExit(Int32, String)

    var errorDescription: String? {
        switch self {
        case .commandNotFound(let cmd):
            return "Command not found: \(cmd)"
        case .nonZeroExit(let code, let stderr):
            return "Exit \(code): \(stderr)"
        }
    }
}

struct Shell {
    /// Runs a command synchronously. Returns stdout on success, throws on failure.
    @discardableResult
    static func run(_ launchPath: String, args: [String], environment: [String: String]? = nil) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args

        if let env = environment {
            var merged = ProcessInfo.processInfo.environment
            merged.merge(env) { _, new in new }
            process.environment = merged
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let outStr = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw ShellError.nonZeroExit(process.terminationStatus, errStr.isEmpty ? outStr : errStr)
        }
        return outStr
    }

    /// Async wrapper using a detached Task.
    static func runAsync(_ launchPath: String, args: [String], environment: [String: String]? = nil) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try Shell.run(launchPath, args: args, environment: environment)
        }.value
    }

    /// Launches a process and returns a handle that can be cancelled.
    /// Wraps the command in a login shell so the user's full PATH (nvm, homebrew, etc.) is available.
    static func launchCancellable(_ launchPath: String, args: [String]) throws -> CancellableProcess {
        let process = Process()
        let escaped = ([launchPath] + args).map { arg in
            "'\(arg.replacingOccurrences(of: "'", with: "'\\''"))'"
        }.joined(separator: " ")
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-ilc", escaped]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        return CancellableProcess(process: process, stdout: stdout, stderr: stderr)
    }
}

/// A running process that can be cancelled or awaited.
final class CancellableProcess: @unchecked Sendable {
    let process: Process
    private let stdout: Pipe
    private let stderr: Pipe
    private var stderrAccumulator = Data()
    private let lock = NSLock()

    init(process: Process, stdout: Pipe, stderr: Pipe) {
        self.process = process
        self.stdout = stdout
        self.stderr = stderr
    }

    /// Observes stderr output in real time. The callback fires on a background queue
    /// each time new data arrives. Call this *before* `waitForExit`.
    func observeStderr(handler: @escaping (String) -> Void) {
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.lock.lock()
            self?.stderrAccumulator.append(data)
            self?.lock.unlock()
            if let text = String(data: data, encoding: .utf8) {
                handler(text)
            }
        }
    }

    /// Waits for the process to finish. Throws on non-zero exit.
    func waitForExit() async throws -> String {
        try await Task.detached(priority: .userInitiated) { [process, stdout, stderr, lock] in
            process.waitUntilExit()
            stderr.fileHandleForReading.readabilityHandler = nil
            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            // Read any remaining stderr data
            let remaining = stderr.fileHandleForReading.readDataToEndOfFile()
            lock.lock()
            let errStr = String(data: remaining, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            lock.unlock()
            let outStr = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard process.terminationStatus == 0 else {
                throw ShellError.nonZeroExit(process.terminationStatus, errStr.isEmpty ? outStr : errStr)
            }
            return outStr
        }.value
    }

    /// Terminates the process immediately.
    func cancel() {
        stderr.fileHandleForReading.readabilityHandler = nil
        if process.isRunning { process.terminate() }
    }
}
