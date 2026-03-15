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

    func testSwitchToClaudeWithTokenCallsSwitcher() async throws {
        let testToken = """
        {"claudeAiOauth":{"accessToken":"sk-test","refreshToken":"rt-test","expiresAt":9999999999,"subscriptionType":"test"}}
        """

        // Create workspace with token
        var ws = Workspace(name: "TestSwitch")
        ws.accounts.append(Account(
            displayName: "TestClaude",
            payload: .claudeCode(ClaudeCodePayload(
                keychainAccount: "test-user",
                label: "Test",
                tokenSnapshot: Data(testToken.utf8)
            ))
        ))

        // switchTo attempts to write to Keychain via security CLI.
        // It may fail due to ACL restrictions in test environments,
        // but should not crash or return unexpected error types.
        let errors = await SwitcherService.switchTo(workspace: ws)
        // If it succeeds, great. If it fails, verify it's a shell error (ACL denial).
        for error in errors {
            XCTAssertTrue(
                error.underlying is ShellError,
                "Expected ShellError, got: \(type(of: error.underlying)) - \(error.underlying.localizedDescription)"
            )
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
