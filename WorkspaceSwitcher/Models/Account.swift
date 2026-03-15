import Foundation

enum AccountType: String, Codable {
    case claudeCode
    case gitHub
}

struct ClaudeCodePayload: Codable, Equatable {
    /// The kSecAttrAccount value identifying this Claude CLI account in Keychain.
    /// Typically the user's email address or a unique identifier.
    var keychainAccount: String
    /// Human-readable label (email or username) shown in Settings.
    var label: String
    /// Snapshot of the OAuth token data from Keychain at discovery time.
    /// Used to restore the credential when switching workspaces.
    var tokenSnapshot: Data?
}

struct GitHubPayload: Codable, Equatable {
    var username: String
    var hostname: String  // e.g. "github.com" or GHE hostname
}

enum AccountPayload: Codable, Equatable {
    case claudeCode(ClaudeCodePayload)
    case gitHub(GitHubPayload)
}

struct Account: Identifiable, Codable {
    var id: UUID
    var type: AccountType
    var displayName: String
    var payload: AccountPayload

    init(id: UUID = UUID(), displayName: String, payload: AccountPayload) {
        self.id = id
        self.displayName = displayName
        switch payload {
        case .claudeCode: self.type = .claudeCode
        case .gitHub: self.type = .gitHub
        }
        self.payload = payload
    }
}
