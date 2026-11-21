import Foundation

/// Follows Bluesky profiles through the public AppView API without signing in.
public final class BlueskyProvider: Sendable {

    public nonisolated static let host = "bsky.app"

    public nonisolated static let reservedHandles: Set<String> = [
        "search", "notifications", "settings", "feeds", "lists",
        "messages", "starter-pack", "starter-pack-short",
        "hashtag", "support", "intent"
    ]

    nonisolated static let nonProfileSubpaths: Set<String> = ["feed", "lists"]

    public nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://bsky.app/profile/\(handle)")
    }

    public nonisolated static func isValidHandle(_ handle: String) -> Bool {
        guard !handle.isEmpty else { return false }
        return !reservedHandles.contains(handle.lowercased())
    }

    /// Returns true if the URL points to a specific Bluesky post
    /// (`/profile/{handle}/post/{rkey}`).
    public nonisolated static func isBlueskyPostURL(_ url: URL) -> Bool {
        guard matchesHost(url.host) else { return false }
        let components = url.pathComponents
        return components.count >= 5
            && components[1].lowercased() == "profile"
            && components[3].lowercased() == "post"
    }
    public func fetchProfile(handle: String) async -> BlueskyProfileFetchResult {
        await performFetch(handle: handle)
    }
}
