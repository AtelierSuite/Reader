import Foundation

extension DLsiteProvider: WebFeedProvider {

    public static func refresh(
        feed: Feed,
        on manager: FeedManager,
        options: FeedRefreshOptions
    ) async throws {
        guard let target = DLsiteFeedTarget(feedURL: feed.url) else { return }
        let feedID = feed.id
        let existingURLs = await Task.detached {
            (try? DatabaseManager.shared.existingArticleURLs(forFeedID: feedID)) ?? []
        }.value
        let includesAdultContent = await hasAdultContentCookie()
        let content = try await fetchContent(
            for: target, excluding: existingProductIDs(in: existingURLs), includesAdultContent: includesAdultContent
        )
        log("DLsite", "fetched id=\(feed.id) feed=\(target.feedURL) new=\(content.items.count)")
        try await manager.storeProviderFeedContent(content, for: feed, options: options, logTag: "DLsite")
    }

    nonisolated static func fetchContent(
        for target: DLsiteFeedTarget, excluding existingProductIDs: Set<String>, includesAdultContent: Bool
    ) async throws -> ProviderFeedContent {
        let listedWorks = try await fetchListedWorks(for: target, includesAdultContent: includesAdultContent)
        let newWorks = listedWorks.filter { !existingProductIDs.contains($0.productID) }
        let infos = try await fetchWorkInfo(
            newWorks.map(\.productID), shop: target.shop, includesAdultContent: includesAdultContent
        )
        let items = newWorks.compactMap { listed -> ArticleInsertItem? in
            let info = infos[listed.productID]
            if info?.isAdult ?? target.shop.requiresAdultContentGate, !includesAdultContent {
                return nil
            }
            return articleItem(for: listed, info: info, shop: target.shop)
        }
        return ProviderFeedContent(items: items, title: feedTitle(for: target, listedWorks: listedWorks, infos: infos))
    }

    private nonisolated static func feedTitle(
        for target: DLsiteFeedTarget, listedWorks: [DLsiteListedWork], infos: [String: DLsiteWorkInfo]
    ) -> String? {
        switch target.source {
        case .circle: nil
        case .series: infos.values.lazy.compactMap(\.titleName).first
        case .creator(let name): name
        }
    }

    nonisolated static func existingProductIDs(in urls: Set<String>) -> Set<String> {
        Set(urls.compactMap { url in
            guard let range = url.range(of: "/product_id/") else { return nil }
            let productID = url[range.upperBound...].prefix { $0.isLetter || $0.isNumber }
            return productID.isEmpty ? nil : String(productID)
        })
    }

    nonisolated static func articleItem(
        for listed: DLsiteListedWork, info: DLsiteWorkInfo?, shop: DLsiteShop
    ) -> ArticleInsertItem {
        let coverURL = absoluteImageURL(info?.workImage) ?? listed.coverURL
        var imageURLs: [String] = []
        for imageURL in [coverURL].compactMap(\.self) + listed.sampleImageURLs where !imageURLs.contains(imageURL) {
            imageURLs.append(imageURL)
        }
        let authors = [listed.circleName].compactMap(\.self) + listed.creatorNames
        return ArticleInsertItem(
            title: info?.workName ?? listed.title ?? listed.productID,
            url: workPageURL(shop: info?.shop ?? shop, productID: listed.productID),
            data: ArticleInsertData(
                author: authors.isEmpty ? nil : authors.joined(separator: " / "),
                content: imageURLs
                    .map { "<figure><img src=\"\(RSSParser.escapeXMLAttribute($0))\"></figure>" }
                    .joined(),
                imageURL: coverURL,
                carouselImageURLs: imageURLs.count > 1 ? imageURLs : [],
                publishedDate: info?.publishedDate
            )
        )
    }
}
