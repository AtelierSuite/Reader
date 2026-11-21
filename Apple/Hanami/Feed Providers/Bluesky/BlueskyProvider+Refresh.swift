import Foundation

extension BlueskyProvider: WebFeedProvider {

    public static func refresh(
        feed: Feed,
        on manager: FeedManager,
        options: FeedRefreshOptions
    ) async throws {
        guard let target = BlueskyFeedTarget(feedURL: feed.url) else {
            try await manager.refreshBlueskyFeed(
                feed,
                reloadData: options.reloadData,
                skipImagePreload: options.skipImagePreload,
                runNLP: options.runNLP,
                contentOnly: options.contentOnly
            )
            return
        }
        let pageCount = feed.lastFetched == nil ? firstFetchPageCount : 1
        let content: ProviderFeedContent
        do {
            content = try await fetchTargetContent(target, pageCount: pageCount)
        } catch BlueskyAPIError.authenticationRequired {
            log("BlueskyFeed", "refresh skipped id=\(feed.id) - \(target.atURI) requires signing in to Bluesky")
            return
        }
        log("BlueskyFeed", "fetched id=\(feed.id) feed=\(target.feedURL) posts=\(content.items.count)")
        try await manager.storeProviderFeedContent(content, for: feed, options: options, logTag: "BlueskyFeed")
    }
}
