import Foundation
import Security

protocol TokenStorage {
    func read() throws -> String?
    func save(_ token: String) throws
    func remove() throws
}

struct KeychainStore: TokenStorage {
    let environment: String
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.ceksepet.ios.session",
         kSecAttrAccount as String: environment]
    }
    func read() throws -> String? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { throw ClientError.keychain(status) }
        return value
    }
    func save(_ token: String) throws {
        let attributes: [String: Any] = [kSecValueData as String: Data(token.utf8),
                                       kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw ClientError.keychain(status) }
        let insertStatus = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        guard insertStatus == errSecSuccess else { throw ClientError.keychain(insertStatus) }
    }
    func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw ClientError.keychain(status) }
    }
}
