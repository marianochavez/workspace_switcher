import XCTest
@testable import WorkspaceSwitcher

final class GitHubSwitcherTests: XCTestCase {

    // MARK: - parseAuthStatus

    func testParseAuthStatusSingleAccount() {
        let output = """
        github.com
          ✓ Logged in to github.com account octocat (keyring)
          - Active account: true
          - Git operations protocol: https
          - Token: ghp_****
          - Token scopes: 'gist', 'read:org', 'repo', 'workflow'
        """
        let accounts = GitHubSwitcher.parseAuthStatus(output)
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].username, "octocat")
        XCTAssertEqual(accounts[0].hostname, "github.com")
    }

    func testParseAuthStatusMultipleAccounts() {
        let output = """
        github.com
          ✓ Logged in to github.com account personal-user (keyring)
          - Active account: true

          ✓ Logged in to github.com account work-user (keyring)
          - Active account: false
        """
        let accounts = GitHubSwitcher.parseAuthStatus(output)
        XCTAssertEqual(accounts.count, 2)
        XCTAssertEqual(accounts[0].username, "personal-user")
        XCTAssertEqual(accounts[1].username, "work-user")
    }

    func testParseAuthStatusGHEHostname() {
        let output = """
        github.enterprise.com
          ✓ Logged in to github.enterprise.com account admin (keyring)
          - Active account: true
        """
        let accounts = GitHubSwitcher.parseAuthStatus(output)
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].hostname, "github.enterprise.com")
        XCTAssertEqual(accounts[0].username, "admin")
    }

    func testParseAuthStatusEmptyOutput() {
        let accounts = GitHubSwitcher.parseAuthStatus("")
        XCTAssertTrue(accounts.isEmpty)
    }

    func testParseAuthStatusNoAccountLines() {
        let output = """
        You are not logged into any GitHub hosts. Run gh auth login to authenticate.
        """
        let accounts = GitHubSwitcher.parseAuthStatus(output)
        XCTAssertTrue(accounts.isEmpty)
    }

    func testParseAuthStatusMixedHosts() {
        let output = """
        github.com
          ✓ Logged in to github.com account user1 (keyring)
          - Active account: true

        ghe.company.com
          ✓ Logged in to ghe.company.com account user2 (keyring)
          - Active account: true
        """
        let accounts = GitHubSwitcher.parseAuthStatus(output)
        XCTAssertEqual(accounts.count, 2)
        XCTAssertEqual(accounts[0].hostname, "github.com")
        XCTAssertEqual(accounts[0].username, "user1")
        XCTAssertEqual(accounts[1].hostname, "ghe.company.com")
        XCTAssertEqual(accounts[1].username, "user2")
    }

    // MARK: - ghPath

    func testGhPathFindsGhIfInstalled() {
        // gh should be installed on this dev machine
        let path = GitHubSwitcher.ghPath()
        if path != nil {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path!))
        }
        // Not asserting non-nil since gh might not be installed in CI
    }
}
