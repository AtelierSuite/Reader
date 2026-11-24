import Foundation

actor BlueskyPreferencesCache {

    static let shared = BlueskyPreferencesCache()

    private let cacheLifetime: TimeInterval = 900
    private var cachedPreferences: BlueskyModerationPreferences?
    private var cachedAt: Date?

    func currentPreferences() async -> BlueskyModerationPreferences {
        guard BlueskyProvider.hasSession() else {
            return .signedOut
        }
        if let cachedPreferences, let cachedAt,
           Date().timeIntervalSince(cachedAt) < cacheLifetime {
            return cachedPreferences
        }

        do {
            let root = try await BlueskyProvider.xrpc(
                "app.bsky.actor.getPreferences",
                query: [],
                requireAuth: true,
                useAppViewProxy: false,
                includeLabelers: false
            )
            let rawPreferences = (root["preferences"] as? [[String: Any]]) ?? []
            let parsed = BlueskyModerationPreferences.parse(preferences: rawPreferences)
            cachedPreferences = parsed
            cachedAt = Date()
            return parsed
        } catch {
            log("BlueskyModeration", "getPreferences failed - \(error.localizedDescription)")
            return cachedPreferences ?? .signedInDefault
        }
    }

    func labelerHeaderValue() async -> String? {
        let preferences = await currentPreferences()
        guard !preferences.labelerDIDs.isEmpty else { return nil }
        return preferences.labelerDIDs.joined(separator: ",")
    }

    func invalidate() {
        cachedPreferences = nil
        cachedAt = nil
    }
}
