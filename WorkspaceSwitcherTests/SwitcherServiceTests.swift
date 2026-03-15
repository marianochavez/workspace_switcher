import XCTest
@testable import WorkspaceSwitcher

final class SwitcherServiceTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkspaceSwitcherTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - switchTo with empty workspace

    func testSwitchToEmptyWorkspaceReturnsNoErrors() async {
        let ws = Workspace(name: "Empty")
        let errors = await SwitcherService.switchTo(workspace: ws)
        XCTAssertTrue(errors.isEmpty)
    }

    // MARK: - switchTo with missing tokenSnapshot

    func testSwitchToClaudeWithoutTokenReturnsError() async {
        var ws = Workspace(name: "NoToken")
        ws.accounts.append(Account(
            displayName: "Claude",
            payload: .claudeCode(ClaudeCodePayload(
                keychainAccount: "user", label: "User", tokenSnapshot: nil
            ))
        ))
        let errors = await SwitcherService.switchTo(workspace: ws)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors[0].accountName, "Claude")
        XCTAssertTrue(errors[0].underlying.localizedDescription.contains("No token snapshot"))
    }

    // MARK: - switchTo with valid Claude token (using test keychain)

    func testSwitchToClaudeWithTokenWritesToKeychain() async throws {
        let testToken = """
        {"claudeAiOauth":{"accessToken":"sk-test","refreshToken":"rt-test","expiresAt":9999999999,"subscriptionType":"test"}}
        """

        // First, ensure the keychain has a known state by writing via security CLI
        let testService = "Claude Code-credentials"
        let currentToken = try? Shell.run("/usr/bin/security", args: [
            "find-generic-password", "-s", testService, "-w"
        ])

        // Create workspace with token
        var ws = Workspace(name: "TestSwitch")
        ws.accounts.append(Account(
            displayName: "TestClaude",
            payload: .claudeCode(ClaudeCodePayload(
                keychainAccount: "marianochavez",
                label: "Test",
                tokenSnapshot: Data(testToken.utf8)
            ))
        ))

        let errors = await SwitcherService.switchTo(workspace: ws)
        XCTAssertTrue(errors.isEmpty, "Errors: \(errors.map { $0.underlying.localizedDescription })")

        // Verify keychain was updated
        let readToken = try Shell.run("/usr/bin/security", args: [
            "find-generic-password", "-s", testService, "-w"
        ])
        XCTAssertEqual(readToken, testToken)

        // Restore original token
        if let original = currentToken {
            try Shell.run("/usr/bin/security", args: [
                "add-generic-password", "-U", "-s", testService, "-a", "marianochavez", "-w", original
            ])
        }
    }

    // MARK: - SwitchError

    func testSwitchErrorContainsAccountName() {
        let err = SwitchError(
            accountName: "TestAccount",
            underlying: NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "test error"])
        )
        XCTAssertEqual(err.accountName, "TestAccount")
        XCTAssertTrue(err.underlying.localizedDescription.contains("test error"))
    }

    // MARK: - Multiple accounts

    func testSwitchToWorkspaceWithMultipleAccountTypes() async {
        var ws = Workspace(name: "Multi")
        // Claude with no token (will error)
        ws.accounts.append(Account(
            displayName: "Claude",
            payload: .claudeCode(ClaudeCodePayload(
                keychainAccount: "user", label: "User", tokenSnapshot: nil
            ))
        ))
        // GitHub (will attempt switch — may error if user doesn't exist, that's fine)
        ws.accounts.append(Account(
            displayName: "GH",
            payload: .gitHub(GitHubPayload(username: "nonexistent-user-xyz", hostname: "github.com"))
        ))

        let errors = await SwitcherService.switchTo(workspace: ws)
        // At least Claude should error (no token)
        XCTAssertTrue(errors.contains { $0.accountName == "Claude" })
    }
}
