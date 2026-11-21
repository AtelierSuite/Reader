import Foundation

extension TelegramProvider: ProfileFeedProvider {

    public nonisolated static var providerID: String { "telegram" }

    public nonisolated static var domains: Set<String> { ["t.me", "telegram.me"] }

    public nonisolated static var feedURLScheme: String? { nil }

    public nonisolated static func isProfileURL(_ url: URL) -> Bool {
        extractIdentifier(from: url) != nil
    }

    public nonisolated static func extractIdentifier(from url: URL) -> String? {
        guard let host = url.host?.lowercased(), domains.contains(host) else { return nil }
        var segments = url.path.split(separator: "/").map(String.init)
        if segments.first == "s" { segments.removeFirst() }
        guard let name = segments.first, isValidChannelName(name) else { return nil }
        return name
    }

    public nonisolated static func feedURL(for identifier: String) -> String {
        "https://t.me/s/\(identifier)"
    }

    public nonisolated static func isFeedURL(_ url: String) -> Bool {
        identifierFromFeedURL(url) != nil
    }

    public nonisolated static func identifierFromFeedURL(_ url: String) -> String? {
        guard let parsed = URL(string: url),
              parsed.host?.lowercased() == "t.me",
              parsed.path.hasPrefix("/s/") else { return nil }
        return extractIdentifier(from: parsed)
    }

    public nonisolated static func inferredSiteURL(fromFeedURL feedURL: String) -> String? {
        identifierFromFeedURL(feedURL).map { "https://t.me/\($0)" }
    }

    public nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
        guard let channel = extractIdentifier(from: url),
              let result = try? await TelegramProvider().fetchChannel(channel) else {
            return nil
        }
        return DiscoveredFeed(
            title: result.title ?? channel,
            url: feedURL(for: channel),
            siteURL: "https://t.me/\(channel)"
        )
    }
}
