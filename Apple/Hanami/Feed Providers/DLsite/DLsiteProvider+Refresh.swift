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
        let includesAdultContent = hasAdultContentCookie()
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
        let visibleWorks = newWorks.filter { listed in
            includesAdultContent || !(infos[listed.productID]?.isAdult ?? target.shop.requiresAdultContentGate)
        }
        let extras = await fetchExtras(
            for: visibleWorks.map { ($0, infos[$0.productID]?.shop ?? target.shop) },
            includesAdultContent: includesAdultContent
        )
        let items = visibleWorks.enumerated().map { index, listed in
            articleItem(for: listed, info: infos[listed.productID], extras: extras[index], shop: target.shop)
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
        for listed: DLsiteListedWork, info: DLsiteWorkInfo?, extras: DLsiteWorkExtras, shop: DLsiteShop
    ) -> ArticleInsertItem {
        let content = DLsiteArticleContent(
            coverURL: absoluteImageURL(info?.workImage) ?? listed.coverURL,
            listedSampleURLs: listed.sampleImageURLs,
            detail: extras.detail,
            description: extras.description,
            circleName: listed.circleName,
            listedCreatorNames: listed.creatorNames
        )
        let imageURLs = content.imageURLs
        return ArticleInsertItem(
            title: info?.workName ?? listed.title ?? listed.productID,
            url: workPageURL(shop: info?.shop ?? shop, productID: listed.productID),
            data: ArticleInsertData(
                author: content.authorLine,
                summary: content.summary,
                content: content.html,
                imageURL: imageURLs.first,
                carouselImageURLs: imageURLs.count > 1 ? imageURLs : [],
                publishedDate: info?.publishedDate
            )
        )
    }

    private nonisolated static func fetchExtras(
        for works: [(work: DLsiteListedWork, shop: DLsiteShop)], includesAdultContent: Bool
    ) async -> [DLsiteWorkExtras] {
        await withTaskGroup(of: (Int, DLsiteWorkExtras).self) { group in
            for (index, (work, shop)) in works.enumerated() {
                group.addTask {
                    async let detail = fetchProductDetail(
                        work.productID, shop: shop, includesAdultContent: includesAdultContent
                    )
                    let description = index < descriptionsPerRefresh
                        ? await fetchDescription(work.productID, shop: shop, includesAdultContent: includesAdultContent)
                        : []
                    return (index, DLsiteWorkExtras(detail: await detail, description: description))
                }
            }
            var extras = Array(repeating: DLsiteWorkExtras(detail: nil, description: []), count: works.count)
            for await (index, workExtras) in group {
                extras[index] = workExtras
            }
            return extras
        }
    }
}

nonisolated struct DLsiteWorkExtras: Sendable {
    let detail: DLsiteProductDetail?
    let description: [DLsiteDescriptionSection]
}
