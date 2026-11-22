import Foundation

extension DLsiteProvider: ProfileFeedProvider {

    public nonisolated static var providerID: String { "dlsite" }

    public nonisolated static var domains: Set<String> { ["dlsite.com"] }

    public nonisolated static var feedURLScheme: String? { circleScheme }

    public nonisolated static func isProfileURL(_ url: URL) -> Bool {
        if case .feed = DLsitePageLink(url: url) { return true }
        return false
    }

    public nonisolated static func extractIdentifier(from url: URL) -> String? {
        guard case .feed(let target) = DLsitePageLink(url: url) else { return nil }
        return target.feedURL
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
        DLsiteFeedTarget(feedURL: feedURL)?.siteURL
    }

    public nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
        guard case .feed(let target) = DLsitePageLink(url: url) else { return nil }
        return await discoveredFeed(for: target)
    }

    public nonisolated static func isWorkPageURL(_ url: URL) -> Bool {
        if case .work = DLsitePageLink(url: url) { return true }
        return false
    }

    /// A work page offers its circle and, when it belongs to one, its series.
    public nonisolated static func discoveredFeeds(forWorkPageURL url: URL) async -> [DiscoveredFeed] {
        guard case .work(let pageShop, let productID) = DLsitePageLink(url: url),
              let info = try? await fetchWorkInfo([productID], shop: pageShop, includesAdultContent: true)[productID]
        else { return [] }
        let shop = info.shop ?? pageShop
        var feeds: [DiscoveredFeed] = []
        if let makerID = info.makerID, DLsiteFeedTarget.isID(makerID, prefix: "RG"),
           let circleFeed = await discoveredFeed(for: DLsiteFeedTarget(shop: shop, source: .circle(makerID))) {
            feeds.append(circleFeed)
        }
        if let titleID = info.titleID, DLsiteFeedTarget.isID(titleID, prefix: "SRI") {
            let target = DLsiteFeedTarget(shop: shop, source: .series(titleID))
            feeds.append(DiscoveredFeed(title: info.titleName ?? titleID, url: target.feedURL, siteURL: target.siteURL))
        }
        return feeds
    }

    public nonisolated static func requiresAdultContentGate(feedURL: String) -> Bool {
        DLsiteFeedTarget(feedURL: feedURL)?.shop.requiresAdultContentGate ?? false
    }

    private nonisolated static func discoveredFeed(for target: DLsiteFeedTarget) async -> DiscoveredFeed? {
        guard let title = await feedTitle(for: target) else { return nil }
        return DiscoveredFeed(title: title, url: target.feedURL, siteURL: target.siteURL)
    }
}
