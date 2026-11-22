import Foundation

/// Site-specific clean-up applied to a parsed feed before its entries are stored.
nonisolated protocol FeedDialect {
    static func matches(feedURL: URL, feed: ParsedFeed) -> Bool
    static func refine(_ article: ParsedArticle, feedURL: URL) -> ParsedArticle
    static func refineFeedTitle(_ title: String) -> String
    /// Adds what the feed leaves out by asking the site, once per changed feed.
    static func enrich(_ feed: ParsedFeed, feedURL: URL, feedID: Int64) async -> ParsedFeed
}

nonisolated extension FeedDialect {
    static func refineFeedTitle(_ title: String) -> String { title }
    static func enrich(_ feed: ParsedFeed, feedURL _: URL, feedID _: Int64) async -> ParsedFeed { feed }
}

public nonisolated enum FeedDialects {

    nonisolated(unsafe) static let all: [any FeedDialect.Type] = [
        TumblrDialect.self,
        LemmyDialect.self,
        LetterboxdDialect.self,
        QiitaDialect.self,
        HatenaBlogDialect.self,
        HatenaBookmarkDialect.self,
        ZennDialect.self,
        MisskeyDialect.self,
        GitHubDialect.self
    ]

    public static func refine(_ feed: ParsedFeed, feedURL: String) -> ParsedFeed {
        guard let url = URL(string: feedURL),
              let dialect = all.first(where: { $0.matches(feedURL: url, feed: feed) }) else { return feed }
        var refined = feed
        refined.title = dialect.refineFeedTitle(feed.title)
        refined.articles = feed.articles.map { dialect.refine($0, feedURL: url) }
        return refined
    }

    public static func enrich(_ feed: ParsedFeed, feedURL: String, feedID: Int64) async -> ParsedFeed {
        guard let url = URL(string: feedURL),
              let dialect = all.first(where: { $0.matches(feedURL: url, feed: feed) }) else { return feed }
        return await dialect.enrich(feed, feedURL: url, feedID: feedID)
    }
}
