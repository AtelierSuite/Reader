import Foundation

extension NetflixProvider: WebFeedProvider {

    public static func refresh(
        feed: Feed,
        on manager: FeedManager,
        options: FeedRefreshOptions
    ) async throws {
        if let lastFetched = feed.lastFetched, Date().timeIntervalSince(lastFetched) < refreshInterval {
            return
        }
        guard let showID = showID(fromFeedURL: feed.url) else { return }
        let feedID = feed.id
        let existingURLs = await Task.detached {
            (try? DatabaseManager.shared.existingArticleURLs(forFeedID: feedID)) ?? []
        }.value
        let show = try await fetchShow(videoID: showID)
        let items = newEpisodeItems(in: show, existingURLs: existingURLs, seenAt: Date())
        log("Netflix", "fetched id=\(feed.id) show=\(showID) new=\(items.count)")
        try await manager.storeProviderFeedContent(
            ProviderFeedContent(items: items, title: show.title),
            for: feed,
            options: options,
            logTag: "Netflix"
        )
    }

    /// Netflix gives no episode dates, so new episodes are dated when first seen, in episode order.
    /// A new follow starts from the latest season, and later refreshes never reach back past the seasons it knows.
    nonisolated static func newEpisodeItems(
        in show: NetflixShow, existingURLs: Set<String>, seenAt: Date
    ) -> [ArticleInsertItem] {
        let firstKnownSeason = show.seasons.firstIndex { season in
            season.episodes.contains { existingURLs.contains(watchURL(for: $0.episodeID)) }
        }
        let seasons = show.seasons[(firstKnownSeason ?? max(show.seasons.count - 1, 0))...]
        let newEpisodes = seasons.flatMap { season in
            season.episodes.map { (season: season, episode: $0) }
        }.filter { !existingURLs.contains(watchURL(for: $0.episode.episodeID)) }
        return newEpisodes.enumerated().map { index, entry in
            let publishedDate = seenAt.addingTimeInterval(-Double(newEpisodes.count - 1 - index))
            return NetflixEpisodeItem(show: show, season: entry.season, episode: entry.episode)
                .articleItem(publishedDate: publishedDate)
        }
    }
}
