import Foundation

public extension FeedManager {

    var hasBlueskyFollowingFeed: Bool {
        let followingURL = BlueskyFeedTarget.following.feedURL
        return feeds.contains { $0.url == followingURL }
    }

    func hasBlueskyFeed(url: String) -> Bool {
        feeds.contains { $0.url == url }
    }

    func addBlueskyFollowingFeed() async throws {
        let target = BlueskyFeedTarget.following
        _ = try await addFeedFetchingMetadata(
            url: target.feedURL,
            title: String(localized: "Bluesky.Following.FeedTitle", table: "Integrations"),
            siteURL: target.siteURL
        )
    }

    @discardableResult
    func addBlueskySavedFeeds(_ savedFeeds: [BlueskySavedFeed]) async -> Int {
        var addedCount = 0
        for savedFeed in savedFeeds {
            guard !hasBlueskyFeed(url: savedFeed.feedURL) else { continue }
            do {
                _ = try await addFeedFetchingMetadata(
                    url: savedFeed.feedURL,
                    title: savedFeed.title,
                    siteURL: savedFeed.siteURL
                )
                addedCount += 1
            } catch {
                log("BlueskyFeed", "Failed to add saved feed \(savedFeed.feedURL) - \(error.localizedDescription)")
            }
        }
        return addedCount
    }
}
