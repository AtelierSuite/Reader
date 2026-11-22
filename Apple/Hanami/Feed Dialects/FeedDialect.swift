import Foundation

/// Site-specific clean-up applied to a parsed feed before its entries are stored.
nonisolated protocol FeedDialect {
    static func matches(feedURL: URL, feed: ParsedFeed) -> Bool
    static func refine(_ article: ParsedArticle, feedURL: URL) -> ParsedArticle
    static func refineFeedTitle(_ title: String) -> String
}

nonisolated extension FeedDialect {
    static func refineFeedTitle(_ title: String) -> String { title }
}

public nonisolated enum FeedDialects {

    nonisolated(unsafe) static let all: [any FeedDialect.Type] = [
        TumblrDialect.self,
        LemmyDialect.self,
        LetterboxdDialect.self,
        QiitaDialect.self,
        HatenaBlogDialect.self,
        HatenaBookmarkDialect.self,
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
}
