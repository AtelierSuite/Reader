import Foundation

extension PixivProvider: ProfileFeedProvider {

    public nonisolated static var providerID: String { "pixiv" }

    public nonisolated static var enabledFlagKey: String? { "Labs.PixivFeeds" }

    public nonisolated static var domains: Set<String> { ["pixiv.net", "pixiv.me"] }

    public nonisolated static var feedURLScheme: String? { userScheme }

    public nonisolated static func isProfileURL(_ url: URL) -> Bool {
        PixivPageLink(url: url) != nil
    }

    public nonisolated static func extractIdentifier(from url: URL) -> String? {
        PixivFeedTarget(pageURL: url)?.feedURL
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
        PixivFeedTarget(feedURL: feedURL)?.siteURL
    }

    public nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
        guard let target = await resolveTarget(for: url) else { return nil }
        let title: String
        switch target.source {
        case .user(let userID):
            guard let user = try? await fetchUser(userID), let name = user.name else { return nil }
            title = name
        case .following:
            guard hasSession() else { return nil }
            title = String(localized: "Pixiv.Following.FeedTitle", table: "Integrations")
        case .tag(let tag):
            title = "#\(tag)"
        case .ranking(let mode):
            title = rankingTitle(for: mode)
        }
        return DiscoveredFeed(title: title, url: target.feedURL, siteURL: target.siteURL)
    }

    nonisolated static func resolveTarget(for url: URL) async -> PixivFeedTarget? {
        switch PixivPageLink(url: url) {
        case .feed(let target):
            return await novelsTargetIfWriter(target, pageURL: url) ?? target
        case .shortLink(let shortURL):
            return await resolveShortLink(shortURL)
        case .artwork(let illustID):
            guard let userID = try? await fetchIllustDetail(illustID).userId else { return nil }
            return PixivFeedTarget(source: .user(userID))
        case .novel(let novelID):
            guard let userID = try? await fetchNovelDetail(novelID).userId else { return nil }
            return PixivFeedTarget(source: .user(userID), works: .novels)
        case .none:
            return nil
        }
    }

    /// A bare profile URL of someone who only writes novels should follow their novels.
    private nonisolated static func novelsTargetIfWriter(
        _ target: PixivFeedTarget, pageURL: URL
    ) async -> PixivFeedTarget? {
        guard case .user(let userID) = target.source, target.works == .illustManga,
              pageURL.path.split(separator: "/").last == Substring(userID),
              let profile = try? await fetchProfileAll(userID),
              profile.newestIllustMangaIDs.isEmpty, !profile.newestNovelIDs.isEmpty else { return nil }
        return PixivFeedTarget(source: .user(userID), works: .novels)
    }

    private nonisolated static func resolveShortLink(_ url: URL) async -> PixivFeedTarget? {
        var request = URLRequest.sakura(url: url, timeoutInterval: 15)
        request.httpMethod = "HEAD"
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let resolvedURL = response.url,
              let target = PixivFeedTarget(pageURL: resolvedURL) else { return nil }
        return await novelsTargetIfWriter(target, pageURL: resolvedURL) ?? target
    }

    nonisolated static func rankingTitle(for mode: String) -> String {
        String(localized: "Pixiv.Ranking.FeedTitle \(mode)", table: "Integrations")
    }
}
