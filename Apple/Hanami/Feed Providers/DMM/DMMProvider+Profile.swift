import Foundation

extension DMMProvider: ProfileFeedProvider {

    public nonisolated static var providerID: String { "dmm" }

    public nonisolated static var domains: Set<String> { ["dmm.com", "dmm.co.jp"] }

    public nonisolated static var feedURLScheme: String? { bookSeriesScheme }

    public nonisolated static func isProfileURL(_ url: URL) -> Bool {
        DMMFeedTarget(pageURL: url) != nil
    }

    public nonisolated static func extractIdentifier(from url: URL) -> String? {
        DMMFeedTarget(pageURL: url)?.feedURL
    }

    public nonisolated static func feedURL(for identifier: String) -> String {
        identifier
    }

    public nonisolated static func isFeedURL(_ url: String) -> Bool {
        schemes.contains { url.hasPrefix($0 + "://") }
    }

    public nonisolated static func identifierFromFeedURL(_ url: String) -> String? {
        isFeedURL(url) ? url : nil
    }

    public nonisolated static func inferredSiteURL(fromFeedURL feedURL: String) -> String? {
        DMMFeedTarget(feedURL: feedURL)?.siteURL
    }

    public nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
        guard let target = DMMFeedTarget(pageURL: url), let title = await feedTitle(for: target) else {
            return nil
        }
        return DiscoveredFeed(title: title, url: target.feedURL, siteURL: target.siteURL)
    }

    /// A FANZA 同人 work page offers its circle and, when it has one, its series.
    public nonisolated static func discoveredFeeds(forWorkPageURL url: URL) async -> [DiscoveredFeed] {
        guard isDoujinHost(url.host), let contentID = doujinContentID(in: url),
              let html = try? await fetchHTML(from: doujinDetailURL(contentID: contentID), sendsAgeCookie: true),
              let detail = parseDoujinDetail(html) else { return [] }
        let circleFeed = detail.circle.map { circle in
            discoveredFeed(DMMFeedTarget(source: .doujinCircle(circle.identifier)), title: circle.name)
        }
        let seriesFeed = detail.series.map { series in
            discoveredFeed(DMMFeedTarget(source: .doujinSeries(series.identifier)), title: series.name)
        }
        return [circleFeed, seriesFeed].compactMap(\.self)
    }

    private nonisolated static func discoveredFeed(_ target: DMMFeedTarget, title: String) -> DiscoveredFeed {
        DiscoveredFeed(title: title, url: target.feedURL, siteURL: target.siteURL)
    }

    nonisolated static func feedTitle(for target: DMMFeedTarget) async -> String? {
        switch target.source {
        case .bookSeries(let shop, let seriesID):
            return try? await fetchBookSeries(seriesID, shop: shop).title
        case .bookAuthor(let shop, let authorID):
            guard let html = try? await fetchHTML(
                from: "https://\(shop.booksHost)/list/?author=\(authorID)", sendsAgeCookie: shop == .adult
            ) else { return nil }
            return parseBookAuthorList(html, shop: shop)?.name
        case .doujinCircle, .doujinSeries:
            guard let html = try? await fetchHTML(from: target.siteURL, sendsAgeCookie: true) else { return nil }
            return parseDoujinList(html)?.name
        }
    }
}
