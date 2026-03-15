import Foundation
import Combine

final class WorkspaceStore: ObservableObject {
    static let shared = WorkspaceStore()

    @Published private(set) var workspaces: [Workspace] = []
    @Published private(set) var activeWorkspaceID: UUID?

    /// Called after any mutation so UI can rebuild the menu.
    var onChange: (() -> Void)?

    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("WorkspaceSwitcher", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("workspaces.json")
    }

    /// Testable initializer with custom storage directory.
    init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("workspaces.json")
    }

    // MARK: - Persistence

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        if let persisted = try? decoder.decode(PersistedState.self, from: data) {
            workspaces = persisted.workspaces
            activeWorkspaceID = persisted.activeWorkspaceID
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let state = PersistedState(workspaces: workspaces, activeWorkspaceID: activeWorkspaceID)
        if let data = try? encoder.encode(state) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: - Mutations

    func addWorkspace(_ workspace: Workspace) {
        workspaces.append(workspace)
        save()
        onChange?()
    }

    func updateWorkspace(_ workspace: Workspace) {
        guard let idx = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
        workspaces[idx] = workspace
        save()
        onChange?()
    }

    func deleteWorkspace(id: UUID) {
        workspaces.removeAll { $0.id == id }
        if activeWorkspaceID == id {
            activeWorkspaceID = nil
        }
        save()
        onChange?()
    }

    func moveWorkspace(from source: IndexSet, to destination: Int) {
        workspaces.move(fromOffsets: source, toOffset: destination)
        save()
        onChange?()
    }

    func setActiveWorkspace(id: UUID?) {
        activeWorkspaceID = id
        save()
        onChange?()
    }

    var activeWorkspace: Workspace? {
        workspaces.first { $0.id == activeWorkspaceID }
    }
}

// MARK: - Codable helper

private struct PersistedState: Codable {
    var workspaces: [Workspace]
    var activeWorkspaceID: UUID?
}
