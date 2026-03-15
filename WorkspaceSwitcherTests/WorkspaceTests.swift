import XCTest
@testable import WorkspaceSwitcher

final class WorkspaceTests: XCTestCase {

    // MARK: - WorkspaceIcon

    func testEmojiDisplayString() {
        let icon = WorkspaceIcon.emoji("🚀")
        XCTAssertEqual(icon.displayString, "🚀")
    }

    func testSfSymbolDisplayString() {
        let icon = WorkspaceIcon.sfSymbol("star.fill")
        XCTAssertEqual(icon.displayString, "star.fill")
    }

    func testWorkspaceIconCodableEmoji() throws {
        let icon = WorkspaceIcon.emoji("💼")
        let data = try JSONEncoder().encode(icon)
        let decoded = try JSONDecoder().decode(WorkspaceIcon.self, from: data)
        XCTAssertEqual(decoded, icon)
    }

    func testWorkspaceIconCodableSfSymbol() throws {
        let icon = WorkspaceIcon.sfSymbol("terminal")
        let data = try JSONEncoder().encode(icon)
        let decoded = try JSONDecoder().decode(WorkspaceIcon.self, from: data)
        XCTAssertEqual(decoded, icon)
    }

    // MARK: - Workspace

    func testWorkspaceDefaults() {
        let ws = Workspace(name: "Test")
        XCTAssertEqual(ws.name, "Test")
        XCTAssertEqual(ws.icon, .emoji("💼"))
        XCTAssertTrue(ws.accounts.isEmpty)
    }

    func testWorkspaceCodableRoundtrip() throws {
        var ws = Workspace(name: "My Work", icon: .sfSymbol("briefcase"))
        ws.accounts.append(Account(
            displayName: "Claude",
            payload: .claudeCode(ClaudeCodePayload(
                keychainAccount: "user", label: "User", tokenSnapshot: Data("t".utf8)
            ))
        ))
        ws.accounts.append(Account(
            displayName: "GH",
            payload: .gitHub(GitHubPayload(username: "u", hostname: "github.com"))
        ))

        let data = try JSONEncoder().encode(ws)
        let decoded = try JSONDecoder().decode(Workspace.self, from: data)
        XCTAssertEqual(decoded.id, ws.id)
        XCTAssertEqual(decoded.name, ws.name)
        XCTAssertEqual(decoded.icon, ws.icon)
        XCTAssertEqual(decoded.accounts.count, 2)
        XCTAssertEqual(decoded.accounts[0].type, .claudeCode)
        XCTAssertEqual(decoded.accounts[1].type, .gitHub)
    }

    func testWorkspaceHasUniqueID() {
        let a = Workspace(name: "A")
        let b = Workspace(name: "B")
        XCTAssertNotEqual(a.id, b.id)
    }
}
