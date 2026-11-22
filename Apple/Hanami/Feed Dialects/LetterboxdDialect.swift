import Foundation

nonisolated enum LetterboxdDialect: FeedDialect {

    static func matches(feedURL: URL, feed _: ParsedFeed) -> Bool {
        feedURL.host?.lowercased() == "letterboxd.com"
    }

    static func refine(_ article: ParsedArticle, feedURL _: URL) -> ParsedArticle {
        var refined = article
        if article.sourceFields["letterboxd:memberLike"] == "Yes" { refined.title += " ♥" }
        if article.sourceFields["letterboxd:rewatch"] == "Yes" { refined.title += " ↻" }
        if refined.content == nil { refined.content = article.descriptionHTML }
        return refined
    }
}
