import Foundation

extension PlayStoreProvider: ProfileFeedProvider {

    public nonisolated static var providerID: String { "play-store" }

    public nonisolated static var domains: Set<String> { ["play.google.com"] }

    public nonisolated static var feedURLScheme: String? { appScheme }

    public nonisolated static func isProfileURL(_ url: URL) -> Bool {
        PlayStoreFeedTarget(pageURL: url) != nil
    }

    public nonisolated static func extractIdentifier(from url: URL) -> String? {
        PlayStoreFeedTarget(pageURL: url)?.feedURL
    }

    public nonisolated static func feedURL(for identifier: String) -> String {
        identifier
    }

    public nonisolated static func isFeedURL(_ url: String) -> Bool {
        url.hasPrefix(appScheme + "://") || url.hasPrefix(developerScheme + "://")
    }

    public nonisolated static func identifierFromFeedURL(_ url: String) -> String? {
        isFeedURL(url) ? url : nil
    }

    public nonisolated static func inferredSiteURL(fromFeedURL feedURL: String) -> String? {
        PlayStoreFeedTarget(feedURL: feedURL)?.siteURL
    }

    public nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
        guard let target = PlayStoreFeedTarget(pageURL: url) else { return nil }
        let provider = PlayStoreProvider()
        let title: String?
        if target.isDeveloper {
            title = (try? await provider.fetchDeveloperPage(for: target))?.developerName
        } else {
            title = (try? await provider.fetchAppDetails(for: target))?.title
        }
        guard let title, !title.isEmpty else { return nil }
        return DiscoveredFeed(title: title, url: target.feedURL, siteURL: target.siteURL)
    }
}
