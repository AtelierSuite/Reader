import Foundation

public nonisolated enum SignedInAccountCache {

    private static let keyPrefix = "SignedInAccount."

    public static func load(for identifier: String) -> String? {
        let stored = UserDefaults.standard.string(forKey: keyPrefix + identifier)
        guard let stored, !stored.isEmpty else { return nil }
        return stored
    }

    public static func save(_ account: String?, for identifier: String) {
        let storageKey = keyPrefix + identifier
        if let account, !account.isEmpty {
            UserDefaults.standard.set(account, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    public static func clear(for identifier: String) {
        UserDefaults.standard.removeObject(forKey: keyPrefix + identifier)
    }
}
