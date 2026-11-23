import Foundation

public nonisolated struct BlueskySessionStore: Sendable {

    public static let shared = BlueskySessionStore(service: "com.tsubuzaki.SakuraRSS.BlueskySession")

    public let service: String
    private let account = "session"

    public init(service: String) {
        self.service = service
    }

    public func save(_ session: BlueskySession) {
        let data: Data
        do {
            data = try JSONEncoder().encode(session)
        } catch {
            log("BlueskySessionStore", "encode failed: \(error)")
            return
        }

        let matchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus = KeychainAccess.perform(matchQuery) { query in
            SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        }
        if updateStatus == errSecItemNotFound {
            var addQuery = matchQuery
            for (key, value) in updateAttributes {
                addQuery[key] = value
            }
            let addStatus = KeychainAccess.perform(addQuery) { query in
                SecItemAdd(query as CFDictionary, nil)
            }
            if addStatus != errSecSuccess {
                log("BlueskySessionStore", "add failed: \(addStatus)")
            }
        } else if updateStatus != errSecSuccess {
            log("BlueskySessionStore", "update failed: \(updateStatus)")
        }
    }

    public func load() -> BlueskySession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = KeychainAccess.perform(query) { query in
            SecItemCopyMatching(query as CFDictionary, &result)
        }
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(BlueskySession.self, from: data)
    }

    public func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        _ = KeychainAccess.perform(query) { query in
            SecItemDelete(query as CFDictionary)
        }
    }
}
