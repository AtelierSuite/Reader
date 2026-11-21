import Foundation

extension BlueskyProvider: ProfileFeedProvider {

    public nonisolated static var providerID: String { "bluesky" }

    public nonisolated static var domains: Set<String> { [host] }

    public nonisolated static var feedURLScheme: String? { nil }

    public nonisolated static func isProfileURL(_ url: URL) -> Bool {
        profileHandle(from: url) != nil || BlueskyFeedTarget(pageURL: url) != nil || isShortLink(url)
    }

    public nonisolated static func extractIdentifier(from url: URL) -> String? {
        profileHandle(from: url)
    }

    nonisolated static func profileHandle(from url: URL) -> String? {
        guard matchesHost(url.host) else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 2,
              components[0].lowercased() == "profile",
              isValidHandle(components[1]) else { return nil }
        if components.count >= 4, nonProfileSubpaths.contains(components[2].lowercased()) {
            return nil
        }
        return components[1]
    }

    public nonisolated static func feedURL(for identifier: String) -> String {
        "https://bsky.app/profile/\(identifier)/rss"
    }

    public nonisolated static func isFeedURL(_ url: String) -> Bool {
        isProfileFeedURL(url) || BlueskyFeedTarget.isFeedURL(url)
    }

    nonisolated static func isProfileFeedURL(_ url: String) -> Bool {
        guard let parsed = URL(string: url),
              matchesHost(parsed.host) else { return false }
        let components = parsed.pathComponents.filter { $0 != "/" }
        guard components.count == 3,
              components[0].lowercased() == "profile",
              components.last?.lowercased() == "rss" else { return false }
        return isValidHandle(components[1])
    }

    public nonisolated static func identifierFromFeedURL(_ url: String) -> String? {
        guard isProfileFeedURL(url),
              let parsed = URL(string: url) else { return nil }
        let components = parsed.pathComponents.filter { $0 != "/" }
        return components.count >= 2 ? components[1] : nil
    }

    public nonisolated static func inferredSiteURL(fromFeedURL feedURL: String) -> String? {
        if let target = BlueskyFeedTarget(feedURL: feedURL) { return target.siteURL }
        return identifierFromFeedURL(feedURL).flatMap { profileURL(for: $0)?.absoluteString }
    }
}
