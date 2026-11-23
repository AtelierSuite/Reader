import Foundation

extension MastodonProvider: WebFeedProvider {

    public static func refresh(
        feed: Feed,
        on manager: FeedManager,
        options: FeedRefreshOptions
    ) async throws {
        guard let target = MastodonFeedTarget(feedURL: feed.url) else { return }
        let statuses = try await fetchTimeline(target: target)
        let items = articleItems(from: statuses)
        log("Mastodon", "fetched id=\(feed.id) host=\(target.host) scope=\(target.scope.rawValue) posts=\(items.count)")

        var profileImageURL: String?
        if !options.contentOnly, feed.lastFetched == nil {
            profileImageURL = await fetchInstance(host: target.host)?.preferredIconURL
        }

        try await manager.storeProviderFeedContent(
            ProviderFeedContent(
                items: items,
                title: nil,
                profileImageURL: profileImageURL
            ),
            for: feed,
            options: options,
            logTag: "Mastodon"
        )
    }
}
