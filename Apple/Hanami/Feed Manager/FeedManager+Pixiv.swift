import Foundation

public extension FeedManager {

    var hasPixivFollowingFeed: Bool {
        let followingURL = PixivFeedTarget.following.feedURL
        return feeds.contains { $0.url == followingURL }
    }

    func addPixivFollowingFeed() async throws {
        let target = PixivFeedTarget.following
        _ = try await addFeedFetchingMetadata(
            url: target.feedURL,
            title: String(localized: "Pixiv.Following.FeedTitle", table: "Integrations"),
            siteURL: target.siteURL
        )
    }
}
