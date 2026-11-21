import Foundation

extension AppStoreProvider: ProfileFeedProvider {

    public nonisolated static var providerID: String { "app-store" }

    public nonisolated static var domains: Set<String> { ["apps.apple.com", "itunes.apple.com"] }

    public nonisolated static var feedURLScheme: String? { appScheme }

    public nonisolated static func isProfileURL(_ url: URL) -> Bool {
        AppStoreFeedTarget(pageURL: url) != nil
    }

    public nonisolated static func extractIdentifier(from url: URL) -> String? {
        AppStoreFeedTarget(pageURL: url)?.feedURL
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
        AppStoreFeedTarget(feedURL: feedURL)?.siteURL
    }

    public nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
        guard let target = AppStoreFeedTarget(pageURL: url),
              let response = try? await AppStoreProvider().lookup(target),
              let title = displayName(for: target, in: response) else { return nil }
        return DiscoveredFeed(title: title, url: target.feedURL, siteURL: target.siteURL)
    }

    nonisolated static func displayName(
        for target: AppStoreFeedTarget, in response: AppStoreLookupResponse
    ) -> String? {
        switch target.kind {
        case .app: response.apps.first?.trackName
        case .developer: response.artistName
        }
    }
}
