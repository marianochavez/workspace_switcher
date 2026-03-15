import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case unexpectedData
    case unhandledError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound: return "Keychain item not found"
        case .unexpectedData: return "Unexpected data format in Keychain"
        case .unhandledError(let s): return "Keychain error: \(s)"
        }
    }
}

struct KeychainItem {
    var service: String
    var account: String
    var label: String?
}

struct KeychainService {

    // MARK: - Claude CLI discovery

    /// Lists all Keychain items with kSecAttrService matching `serviceName`.
    /// Claude CLI uses service name "claude" — each item's account is the user identifier.
    static func listItems(service: String) -> [KeychainItem] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[CFString: Any]] else {
            return []
        }

        return items.compactMap { attrs -> KeychainItem? in
            guard let account = attrs[kSecAttrAccount] as? String else { return nil }
            let label = attrs[kSecAttrLabel] as? String
            return KeychainItem(service: service, account: account, label: label)
        }
    }

    // MARK: - Generic read/write

    static func readPassword(service: String, account: String) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainError.unexpectedData }
            return data
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unhandledError(status)
        }
    }

    static func writePassword(service: String, account: String, data: Data) throws {
        // Try update first
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]

        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status)
        }
    }

    static func deleteItem(service: String, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }
}
