import Foundation

extension NetflixProvider: ProfileFeedProvider {

    public nonisolated static var providerID: String { "netflix" }

    public nonisolated static var domains: Set<String> { ["netflix.com"] }

    public nonisolated static var feedURLScheme: String? { showScheme }

    public nonisolated static func isProfileURL(_ url: URL) -> Bool {
        videoID(fromPageURL: url) != nil
    }

    public nonisolated static func extractIdentifier(from url: URL) -> String? {
        videoID(fromPageURL: url)
    }

    public nonisolated static func feedURL(for identifier: String) -> String {
        feedURL(forShowID: identifier)
    }

    public nonisolated static func inferredSiteURL(fromFeedURL feedURL: String) -> String? {
        showID(fromFeedURL: feedURL).map(titlePageURL(for:))
    }

    public nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
        guard let videoID = videoID(fromPageURL: url),
              let show = try? await fetchShow(videoID: videoID) else { return nil }
        return DiscoveredFeed(
            title: show.title,
            url: feedURL(forShowID: show.showID),
            siteURL: titlePageURL(for: show.showID)
        )
    }
}
