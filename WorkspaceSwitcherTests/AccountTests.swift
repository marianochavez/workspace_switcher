import XCTest
@testable import WorkspaceSwitcher

final class AccountTests: XCTestCase {

    // MARK: - AccountType

    func testAccountTypeRawValues() {
        XCTAssertEqual(AccountType.claudeCode.rawValue, "claudeCode")
        XCTAssertEqual(AccountType.gitHub.rawValue, "gitHub")
    }

    // MARK: - ClaudeCodePayload

    func testClaudeCodePayloadCodableRoundtrip() throws {
        let payload = ClaudeCodePayload(
            keychainAccount: "user@example.com",
            label: "My Account",
            tokenSnapshot: Data("fake-token-json".utf8)
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ClaudeCodePayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    func testClaudeCodePayloadWithNilSnapshot() throws {
        let payload = ClaudeCodePayload(keychainAccount: "user", label: "label", tokenSnapshot: nil)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ClaudeCodePayload.self, from: data)
        XCTAssertNil(decoded.tokenSnapshot)
        XCTAssertEqual(decoded.keychainAccount, "user")
    }

    func testClaudeCodePayloadEquality() {
        let a = ClaudeCodePayload(keychainAccount: "a", label: "A", tokenSnapshot: Data([1, 2, 3]))
        let b = ClaudeCodePayload(keychainAccount: "a", label: "A", tokenSnapshot: Data([1, 2, 3]))
        let c = ClaudeCodePayload(keychainAccount: "a", label: "A", tokenSnapshot: Data([4, 5, 6]))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - GitHubPayload

    func testGitHubPayloadCodableRoundtrip() throws {
        let payload = GitHubPayload(username: "octocat", hostname: "github.com")
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(GitHubPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    // MARK: - AccountPayload

    func testAccountPayloadClaudeCodeCodable() throws {
        let payload = AccountPayload.claudeCode(ClaudeCodePayload(
            keychainAccount: "user", label: "User", tokenSnapshot: nil
        ))
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(AccountPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    func testAccountPayloadGitHubCodable() throws {
        let payload = AccountPayload.gitHub(GitHubPayload(username: "user", hostname: "github.com"))
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(AccountPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    // MARK: - Account

    func testAccountInitSetsTypeFromPayload() {
        let claude = Account(displayName: "Claude", payload: .claudeCode(
            ClaudeCodePayload(keychainAccount: "a", label: "a")
        ))
        XCTAssertEqual(claude.type, .claudeCode)

        let gh = Account(displayName: "GH", payload: .gitHub(
            GitHubPayload(username: "u", hostname: "h")
        ))
        XCTAssertEqual(gh.type, .gitHub)
    }

    func testAccountCodableRoundtrip() throws {
        let account = Account(
            displayName: "Test",
            payload: .claudeCode(ClaudeCodePayload(
                keychainAccount: "user@test.com",
                label: "Test Account",
                tokenSnapshot: Data("token".utf8)
            ))
        )
        let data = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(Account.self, from: data)
        XCTAssertEqual(decoded.id, account.id)
        XCTAssertEqual(decoded.type, account.type)
        XCTAssertEqual(decoded.displayName, account.displayName)
        XCTAssertEqual(decoded.payload, account.payload)
    }

    func testAccountHasUniqueID() {
        let a = Account(displayName: "A", payload: .gitHub(GitHubPayload(username: "a", hostname: "h")))
        let b = Account(displayName: "B", payload: .gitHub(GitHubPayload(username: "b", hostname: "h")))
        XCTAssertNotEqual(a.id, b.id)
    }
}
