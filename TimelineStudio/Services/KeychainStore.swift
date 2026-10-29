import Foundation
import Security

/// Small keychain wrapper. Secrets for this app never go in UserDefaults.
enum KeychainStore {
    static let service = "com.timelinestudio.app"

    static func string(account: String) -> String? {
        var query = base(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String, account: String) {
        let data = Data(value.utf8)
        let status = SecItemCopyMatching(base(account: account) as CFDictionary, nil)
        if status == errSecSuccess {
            let update = [kSecValueData as String: data]
            SecItemUpdate(base(account: account) as CFDictionary, update as CFDictionary)
        } else {
            var add = base(account: account)
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func remove(account: String) {
        SecItemDelete(base(account: account) as CFDictionary)
    }

    private static func base(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
