import XCTest
@testable import WorkspaceSwitcher

final class WorkspaceStoreTests: XCTestCase {

    private var store: WorkspaceStore!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkspaceSwitcherTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = WorkspaceStore(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - CRUD

    func testAddWorkspace() {
        let ws = Workspace(name: "Test")
        store.addWorkspace(ws)
        XCTAssertEqual(store.workspaces.count, 1)
        XCTAssertEqual(store.workspaces.first?.name, "Test")
    }

    func testUpdateWorkspace() {
        var ws = Workspace(name: "Before")
        store.addWorkspace(ws)
        ws.name = "After"
        store.updateWorkspace(ws)
        XCTAssertEqual(store.workspaces.first?.name, "After")
    }

    func testDeleteWorkspace() {
        let ws = Workspace(name: "ToDelete")
        store.addWorkspace(ws)
        XCTAssertEqual(store.workspaces.count, 1)
        store.deleteWorkspace(id: ws.id)
        XCTAssertTrue(store.workspaces.isEmpty)
    }

    func testDeleteNonExistentWorkspaceIsNoOp() {
        let ws = Workspace(name: "Existing")
        store.addWorkspace(ws)
        store.deleteWorkspace(id: UUID())
        XCTAssertEqual(store.workspaces.count, 1)
    }

    func testMoveWorkspace() {
        store.addWorkspace(Workspace(name: "A"))
        store.addWorkspace(Workspace(name: "B"))
        store.addWorkspace(Workspace(name: "C"))

        store.moveWorkspace(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(store.workspaces.map(\.name), ["B", "C", "A"])
    }

    // MARK: - Active Workspace

    func testSetActiveWorkspace() {
        let ws = Workspace(name: "Active")
        store.addWorkspace(ws)
        store.setActiveWorkspace(id: ws.id)
        XCTAssertEqual(store.activeWorkspaceID, ws.id)
        XCTAssertEqual(store.activeWorkspace?.name, "Active")
    }

    func testClearActiveWorkspace() {
        let ws = Workspace(name: "X")
        store.addWorkspace(ws)
        store.setActiveWorkspace(id: ws.id)
        store.setActiveWorkspace(id: nil)
        XCTAssertNil(store.activeWorkspaceID)
        XCTAssertNil(store.activeWorkspace)
    }

    func testDeleteActiveWorkspaceClearsIt() {
        let ws = Workspace(name: "Active")
        store.addWorkspace(ws)
        store.setActiveWorkspace(id: ws.id)
        store.deleteWorkspace(id: ws.id)
        XCTAssertNil(store.activeWorkspaceID)
    }

    // MARK: - Persistence

    func testSaveAndLoad() {
        var ws = Workspace(name: "Persisted", icon: .sfSymbol("star"))
        ws.accounts.append(Account(
            displayName: "Claude",
            payload: .claudeCode(ClaudeCodePayload(
                keychainAccount: "user", label: "User", tokenSnapshot: Data("token".utf8)
            ))
        ))
        store.addWorkspace(ws)
        store.setActiveWorkspace(id: ws.id)
        store.save()

        let store2 = WorkspaceStore(directory: tempDir)
        store2.load()
        XCTAssertEqual(store2.workspaces.count, 1)
        XCTAssertEqual(store2.workspaces.first?.name, "Persisted")
        XCTAssertEqual(store2.workspaces.first?.icon, .sfSymbol("star"))
        XCTAssertEqual(store2.activeWorkspaceID, ws.id)

        if case .claudeCode(let payload) = store2.workspaces.first?.accounts.first?.payload {
            XCTAssertEqual(payload.keychainAccount, "user")
            XCTAssertEqual(payload.tokenSnapshot, Data("token".utf8))
        } else {
            XCTFail("Expected claudeCode payload")
        }
    }

    func testLoadFromEmptyDirectoryStartsEmpty() {
        store.load()
        XCTAssertTrue(store.workspaces.isEmpty)
        XCTAssertNil(store.activeWorkspaceID)
    }

    func testLoadCorruptedFileStartsEmpty() throws {
        let file = tempDir.appendingPathComponent("workspaces.json")
        try Data("not valid json".utf8).write(to: file)
        store.load()
        XCTAssertTrue(store.workspaces.isEmpty)
    }

    // MARK: - onChange callback

    func testOnChangeCalledOnAdd() {
        var called = false
        store.onChange = { called = true }
        store.addWorkspace(Workspace(name: "X"))
        XCTAssertTrue(called)
    }

    func testOnChangeCalledOnDelete() {
        let ws = Workspace(name: "X")
        store.addWorkspace(ws)
        var called = false
        store.onChange = { called = true }
        store.deleteWorkspace(id: ws.id)
        XCTAssertTrue(called)
    }

    func testOnChangeCalledOnUpdate() {
        var ws = Workspace(name: "X")
        store.addWorkspace(ws)
        var called = false
        store.onChange = { called = true }
        ws.name = "Y"
        store.updateWorkspace(ws)
        XCTAssertTrue(called)
    }
}
