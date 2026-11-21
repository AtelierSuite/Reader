import Foundation

extension PixivProvider: WebFeedProvider {

    public static func refresh(
        feed: Feed,
        on manager: FeedManager,
        options: FeedRefreshOptions
    ) async throws {
        guard let target = PixivFeedTarget(feedURL: feed.url) else { return }
        let feedID = feed.id
        let existingURLs = await Task.detached {
            (try? DatabaseManager.shared.existingArticleURLs(forFeedID: feedID)) ?? []
        }.value
        let content = try await fetchContent(for: target, excluding: existingURLs)
        log("Pixiv", "fetched id=\(feed.id) feed=\(target.feedURL) new=\(content.items.count)")
        try await manager.storeProviderFeedContent(content, for: feed, options: options, logTag: "Pixiv")
    }

    nonisolated static func fetchContent(
        for target: PixivFeedTarget, excluding existingURLs: Set<String>
    ) async throws -> ProviderFeedContent {
        switch target.source {
        case .user(let userID):
            let user = try await fetchUser(userID)
            let profile = try await fetchProfileAll(userID)
            let items: [ArticleInsertItem]
            if target.works == .novels {
                let novels = try await fetchUserNovels(userID, profile: profile)
                items = await novelItems(novels, excluding: existingURLs)
            } else {
                let artworks = try await fetchUserArtworks(userID, profile: profile)
                items = await artworkItems(artworks, excluding: existingURLs)
            }
            return ProviderFeedContent(items: items, title: user.name, profileImageURL: user.avatarURL)
        case .following:
            let artworks = try await fetchFollowingArtworks()
            return ProviderFeedContent(items: await artworkItems(artworks, excluding: existingURLs))
        case .tag(let tag):
            let artworks = try await fetchTagArtworks(tag)
            return ProviderFeedContent(items: await artworkItems(artworks, excluding: existingURLs))
        case .ranking(let mode):
            let artworks = try await fetchRankingArtworks(mode)
            return ProviderFeedContent(items: await artworkItems(artworks, excluding: existingURLs))
        case .mangaSeries(let seriesID, _):
            let series = try await fetchMangaSeries(seriesID)
            return ProviderFeedContent(
                items: await artworkItems(series.artworks, excluding: existingURLs),
                title: series.title,
                profileImageURL: series.avatarURL
            )
        case .novelSeries(let seriesID):
            let series = try await fetchNovelSeries(seriesID)
            let novels = try await fetchNovelSeriesContents(seriesID)
            return ProviderFeedContent(
                items: await novelItems(novels, excluding: existingURLs),
                title: series.title,
                profileImageURL: series.profileImageUrl
            )
        }
    }

    private nonisolated static func artworkItems(
        _ artworks: [PixivArtwork], excluding existingURLs: Set<String>
    ) async -> [ArticleInsertItem] {
        let includesRestricted = includesRestrictedWorks
        let newArtworks = artworks.filter { artwork in
            (artwork.restriction == 0 || includesRestricted) && !existingURLs.contains(artwork.pageURL)
        }
        var items: [ArticleInsertItem] = []
        for (index, artwork) in newArtworks.enumerated() {
            let detail = index < illustDetailLimit ? try? await fetchIllustDetail(artwork.id) : nil
            items.append(articleItem(for: artwork, detail: detail))
        }
        return items
    }

    private nonisolated static func novelItems(
        _ novels: [PixivNovel], excluding existingURLs: Set<String>
    ) async -> [ArticleInsertItem] {
        let includesRestricted = includesRestrictedWorks
        let newNovels = novels.filter { novel in
            (novel.restriction == 0 || includesRestricted) && !existingURLs.contains(novel.pageURL)
        }
        var items: [ArticleInsertItem] = []
        for novel in newNovels {
            items.append(await articleItem(for: novel))
        }
        return items
    }
}
