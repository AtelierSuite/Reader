import Foundation

extension DMMProvider: WebFeedProvider {

    public static func refresh(
        feed: Feed,
        on manager: FeedManager,
        options: FeedRefreshOptions
    ) async throws {
        guard let target = DMMFeedTarget(feedURL: feed.url) else { return }
        let feedID = feed.id
        let existingURLs = await Task.detached {
            (try? DatabaseManager.shared.existingArticleURLs(forFeedID: feedID)) ?? []
        }.value
        var content = try await fetchContent(for: target, excluding: existingURLs)
        let now = Date()
        // Preorders stay out until their release date.
        content.items.removeAll { ($0.data.publishedDate ?? now) > now }
        log("DMM", "fetched id=\(feed.id) feed=\(target.feedURL) new=\(content.items.count)")
        try await manager.storeProviderFeedContent(content, for: feed, options: options, logTag: "DMM")
    }

    nonisolated static func fetchContent(
        for target: DMMFeedTarget, excluding existingURLs: Set<String>
    ) async throws -> ProviderFeedContent {
        switch target.source {
        case .bookSeries(let shop, let seriesID):
            let series = try await fetchBookSeries(seriesID, shop: shop)
            if let latestContentID = series.latestContentId,
               existingURLs.contains(bookVolumeURL(seriesID: seriesID, contentID: latestContentID, shop: shop)) {
                return ProviderFeedContent(items: [], title: series.title)
            }
            let volumes = try await fetchBookVolumes(seriesID, shop: shop, count: volumesPerRefresh)
            let items = volumes
                .map { articleItem(for: $0, seriesID: seriesID, shop: shop) }
                .filter { !existingURLs.contains($0.url) }
            return ProviderFeedContent(
                items: items, title: series.title, profileImageURL: volumes.first?.imageUrls?.ps
            )
        case .bookAuthor(let shop, let authorID):
            let html = try await fetchHTML(
                from: "https://\(shop.booksHost)/list/?author=\(authorID)&sort=date", sendsAgeCookie: shop == .adult
            )
            guard let list = parseBookAuthorList(html, shop: shop) else { throw URLError(.cannotParseResponse) }
            let newWorks = unseenWorks(in: list, excluding: existingURLs)
            let items = await concurrentlyMap(newWorks) { work in
                await bookAuthorItem(for: work, shop: shop, author: list.name)
            }
            return ProviderFeedContent(items: items, title: list.name)
        case .doujinCircle, .doujinSeries:
            let html = try await fetchHTML(from: target.siteURL + "sort=date/", sendsAgeCookie: true)
            guard let list = parseDoujinList(html) else { throw URLError(.cannotParseResponse) }
            let newWorks = unseenWorks(in: list, excluding: existingURLs)
            let items = await concurrentlyMap(newWorks) { work in
                let detail = (try? await fetchHTML(from: work.url, sendsAgeCookie: true)).flatMap(parseDoujinDetail)
                return doujinItem(for: work, detail: detail)
            }
            return ProviderFeedContent(items: items, title: list.name)
        }
    }

    /// Lists have no dates, so each refresh looks up a bounded batch and later refreshes backfill the rest.
    private nonisolated static func unseenWorks(
        in list: DMMWorkList, excluding existingURLs: Set<String>
    ) -> [DMMListedWork] {
        Array(list.works.filter { !existingURLs.contains($0.url) }.prefix(detailFetchesPerRefresh))
    }

    private nonisolated static func bookAuthorItem(
        for work: DMMListedWork, shop: DMMFeedTarget.Shop, author: String?
    ) async -> ArticleInsertItem {
        if let seriesID = work.bookSeriesID,
           let volumes = try? await fetchBookVolumes(seriesID, shop: shop, count: 5),
           let volume = volumes.first(where: { $0.contentId == work.contentID }) {
            return articleItem(for: volume, seriesID: seriesID, shop: shop, author: author)
        }
        return listedWorkItem(for: work, imageURLs: [], author: author, publishedDate: nil)
    }

    private nonisolated static func doujinItem(for work: DMMListedWork, detail: DMMDoujinDetail?) -> ArticleInsertItem {
        listedWorkItem(
            for: work,
            imageURLs: detail?.imageURLs ?? [],
            author: work.creator ?? detail?.circle?.name,
            publishedDate: detail?.publishedDate
        )
    }

    private nonisolated static func listedWorkItem(
        for work: DMMListedWork, imageURLs: [String], author: String?, publishedDate: Date?
    ) -> ArticleInsertItem {
        let images = imageURLs.isEmpty ? work.coverURL.map { [$0] } ?? [] : imageURLs
        let imagesHTML = images
            .map { "<figure><img src=\"\(RSSParser.escapeXMLAttribute($0))\"></figure>" }
            .joined()
        return ArticleInsertItem(
            title: work.title,
            url: work.url,
            data: ArticleInsertData(
                author: author,
                content: imagesHTML.isEmpty ? nil : imagesHTML,
                imageURL: work.coverURL ?? images.first,
                carouselImageURLs: images.count > 1 ? images : [],
                publishedDate: publishedDate
            )
        )
    }

    private nonisolated static func concurrentlyMap<Element: Sendable>(
        _ works: [DMMListedWork],
        transform: @escaping @Sendable (DMMListedWork) async -> Element
    ) async -> [Element] {
        var results: [Element] = []
        let batchSize = 6
        for batchStart in stride(from: 0, to: works.count, by: batchSize) {
            let batch = Array(works[batchStart..<min(batchStart + batchSize, works.count)])
            let batchResults = await withTaskGroup(of: (Int, Element).self) { group in
                for (index, work) in batch.enumerated() {
                    group.addTask { (index, await transform(work)) }
                }
                var collected: [(Int, Element)] = []
                for await result in group {
                    collected.append(result)
                }
                return collected.sorted { $0.0 < $1.0 }.map(\.1)
            }
            results += batchResults
        }
        return results
    }
}
