import Foundation

public extension FeedDiscovery {

    /// Links that stand for exactly one feed, such as a Telegram channel or a show in a podcast app.
    nonisolated static func isSingleFeedLink(_ url: URL) -> Bool {
        PodcastLinkResolver.showReference(for: url) != nil || TelegramProvider.isProfileURL(url)
            || DMMProvider.isProfileURL(url)
    }

    nonisolated static func noFeedsMessage(for url: URL?) -> String {
        if let url, isSingleFeedLink(url) {
            return String(localized: "AddFeed.FeedUnavailable", table: "Feeds")
        }
        return String(localized: "AddFeed.NoFeedsFound", table: "Feeds")
    }
}
