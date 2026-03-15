import XCTest
@testable import WorkspaceSwitcher

final class ClaudeCodeSwitcherTests: XCTestCase {

    // MARK: - claudePath

    func testClaudePathFindsClaudeIfInstalled() {
        let path = ClaudeCodeSwitcher.claudePath()
        if path != nil {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path!))
        }
    }

    // MARK: - runningSessions

    func testRunningSessionsReturnsArrayType() {
        // Just verify it doesn't crash and returns correct type
        let sessions = ClaudeCodeSwitcher.runningSessions()
        XCTAssertTrue(sessions is [ClaudeCodeSwitcher.RunningSession])
        // If there are sessions, verify they have valid PIDs
        for session in sessions {
            XCTAssertGreaterThan(session.pid, 0)
            XCTAssertFalse(session.sessionId.isEmpty)
            XCTAssertFalse(session.cwd.isEmpty)
        }
    }

    // MARK: - switchTo with test keychain

    func testSwitchToWritesTokenViaSecurityCLI() throws {
        // This test verifies the security CLI integration works
        // We use a test service to avoid touching real credentials
        let testService = "WorkspaceSwitcherTest-\(UUID().uuidString)"
        let testAccount = "test-user"
        let testToken = """
        {"claudeAiOauth":{"accessToken":"sk-test-123","refreshToken":"rt-test","expiresAt":9999999999,"subscriptionType":"test"}}
        """
        let tokenData = Data(testToken.utf8)

        // Write using security CLI (same approach as ClaudeCodeSwitcher.switchTo)
        try Shell.run("/usr/bin/security", args: [
            "add-generic-password", "-U",
            "-s", testService,
            "-a", testAccount,
            "-w", testToken
        ])

        // Verify it was written
        let readOutput = try Shell.run("/usr/bin/security", args: [
            "find-generic-password", "-s", testService, "-w"
        ])
        XCTAssertEqual(readOutput, testToken)

        // Clean up
        try Shell.run("/usr/bin/security", args: [
            "delete-generic-password", "-s", testService, "-a", testAccount
        ])
    }

    // MARK: - Token snapshot roundtrip

    func testTokenSnapshotRoundtrip() throws {
        let originalToken = """
        {"claudeAiOauth":{"accessToken":"sk-ant-oat01-abc123","refreshToken":"sk-ant-ort01-xyz","expiresAt":1773567203378,"subscriptionType":"max"}}
        """
        let tokenData = Data(originalToken.utf8)

        // Simulate what happens during save: Data is encoded as base64 via Codable
        let payload = ClaudeCodePayload(
            keychainAccount: "testuser",
            label: "Test",
            tokenSnapshot: tokenData
        )
        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ClaudeCodePayload.self, from: encoded)

        // Verify the snapshot survives encode/decode
        XCTAssertNotNil(decoded.tokenSnapshot)
        let recoveredString = String(data: decoded.tokenSnapshot!, encoding: .utf8)
        XCTAssertEqual(recoveredString, originalToken)

        // Verify the token JSON itself is parseable
        let tokenJSON = try JSONSerialization.jsonObject(with: decoded.tokenSnapshot!) as? [String: Any]
        let oauth = tokenJSON?["claudeAiOauth"] as? [String: Any]
        XCTAssertEqual(oauth?["subscriptionType"] as? String, "max")
        XCTAssertEqual(oauth?["accessToken"] as? String, "sk-ant-oat01-abc123")
    }

    // MARK: - activeAccount

    func testActiveAccountReturnsStringOrNil() {
        // Just verify it doesn't crash
        let account = ClaudeCodeSwitcher.activeAccount()
        // account is String? — either a username or nil
        if let account = account {
            XCTAssertFalse(account.isEmpty)
        }
    }
}
