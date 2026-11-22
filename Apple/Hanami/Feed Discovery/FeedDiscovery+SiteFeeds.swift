import Foundation

public extension FeedDiscovery {

    /// Feeds of sites whose pages hide them: behind a bot challenge, without a `<link rel="alternate">`, or on another path.
    func discoverSiteFeeds(for url: URL) async -> [DiscoveredFeed] {
        guard let host = url.host?.lowercased() else { return [] }
        let segments = url.pathComponents.filter { $0 != "/" }
        if let feeds = await gitHubFeeds(host: host, segments: segments) { return feeds }
        let candidate = tumblrFeed(host: host, segments: segments)
            ?? letterboxdFeed(host: host, segments: segments)
            ?? hatenaBookmarkFeed(host: host, segments: segments)
            ?? lemmyFeed(host: host, segments: segments)
        guard let candidate,
              let feed = await Self.probeFeedAt(domain: candidate.host, path: candidate.path) else { return [] }
        return [DiscoveredFeed(title: feed.title, url: feed.url, siteURL: url.absoluteString)]
    }

    // MARK: - Tumblr

    private static let tumblrReservedNames: Set<String> = [
        "www", "explore", "dashboard", "tagged", "search", "login", "register", "settings", "communities",
        "new", "inbox", "likes", "following", "blog", "about", "policy", "privacy", "docs", "apps", "live"
    ]

    private func tumblrFeed(host: String, segments: [String]) -> (host: String, path: String)? {
        if host.hasSuffix(".tumblr.com") {
            let blog = String(host.dropLast(".tumblr.com".count))
            guard !blog.contains("."), !Self.tumblrReservedNames.contains(blog) else {
                return tumblrBlogFeed(named: segments.first)
            }
            return ("\(blog).tumblr.com", "/rss")
        }
        guard host == "tumblr.com" else { return nil }
        return tumblrBlogFeed(named: segments.first)
    }

    private func tumblrBlogFeed(named blog: String?) -> (host: String, path: String)? {
        guard let blog = blog?.lowercased(), !Self.tumblrReservedNames.contains(blog),
              blog.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { return nil }
        return ("\(blog).tumblr.com", "/rss")
    }

    // MARK: - Letterboxd

    private static let letterboxdReservedNames: Set<String> = [
        "film", "films", "list", "lists", "journal", "members", "search", "settings", "activity", "about",
        "pro", "apps", "contact", "legal", "sign-in", "create-account", "year-in-review", "showdown",
        "crew", "actor", "director", "studio", "tag", "reviewers", "video-store", "podcast", "welcome"
    ]

    private func letterboxdFeed(host: String, segments: [String]) -> (host: String, path: String)? {
        guard host == "letterboxd.com" || host == "www.letterboxd.com",
              let member = segments.first?.lowercased(),
              !Self.letterboxdReservedNames.contains(member) else { return nil }
        return ("letterboxd.com", "/\(member)/rss/")
    }

    // MARK: - Hatena Bookmark

    private static let hatenaBookmarkReservedNames: Set<String> = [
        "hotentry", "entrylist", "entry", "q", "search", "site", "ranking", "help", "guide", "api",
        "my", "users", "t", "keyword", "news", "topics", "dictionary"
    ]

    private func hatenaBookmarkFeed(host: String, segments: [String]) -> (host: String, path: String)? {
        guard host == HatenaBookmarkDialect.host, let user = segments.first,
              !Self.hatenaBookmarkReservedNames.contains(user.lowercased()),
              !user.contains(".") else { return nil }
        return (host, "/\(user)/bookmark.rss")
    }

    // MARK: - Lemmy

    /// `/c/linux@lemmy.ml` on another server names a community whose feed only its home server publishes.
    private func lemmyFeed(host: String, segments: [String]) -> (host: String, path: String)? {
        guard segments.count >= 2, segments[0] == "c" || segments[0] == "u" else { return nil }
        let parts = segments[1].split(separator: "@", maxSplits: 1).map(String.init)
        guard let name = parts.first, !name.isEmpty else { return nil }
        let homeHost = parts.count == 2 ? parts[1].lowercased() : host
        return (homeHost, "/feeds/\(segments[0])/\(name).xml?sort=New")
    }

    // MARK: - GitHub

    private static let gitHubReservedOwners: Set<String> = [
        "settings", "orgs", "marketplace", "explore", "topics", "features", "sponsors", "login", "join",
        "notifications", "pulls", "issues", "search", "about", "pricing", "collections", "trending",
        "apps", "enterprise", "customer-stories", "security", "readme", "codespaces", "copilot", "site"
    ]

    private func gitHubFeeds(host: String, segments: [String]) async -> [DiscoveredFeed]? {
        guard host == "github.com" || host == "www.github.com", let owner = segments.first,
              !Self.gitHubReservedOwners.contains(owner.lowercased()),
              segments.last?.hasSuffix(".atom") != true else { return nil }
        guard segments.count >= 2 else {
            guard let feed = await Self.probeFeedAt(domain: "github.com", path: "/\(owner).atom") else { return [] }
            return [DiscoveredFeed(title: owner, url: feed.url, siteURL: "https://github.com/\(owner)")]
        }
        let repository = "/\(owner)/\(segments[1])"
        let siteURL = "https://github.com\(repository)"
        var feeds: [DiscoveredFeed] = []
        for path in ["\(repository)/releases.atom", "\(repository)/tags.atom", "\(repository)/commits.atom"] {
            guard let feed = await Self.probeFeedAt(domain: "github.com", path: path) else { continue }
            feeds.append(DiscoveredFeed(title: feed.title, url: feed.url, siteURL: siteURL))
        }
        return feeds
    }
}
