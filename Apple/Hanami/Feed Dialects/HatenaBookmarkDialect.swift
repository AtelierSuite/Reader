import Foundation

nonisolated enum HatenaBookmarkDialect: FeedDialect {

    static let host = "b.hatena.ne.jp"

    static func matches(feedURL: URL, feed _: ParsedFeed) -> Bool {
        feedURL.host?.lowercased() == host
    }

    /// The feed's own content is a favicon, a cropped thumbnail and bookmark badges, so the linked page is read instead.
    static func refine(_ article: ParsedArticle, feedURL _: URL) -> ParsedArticle {
        var refined = article
        refined.content = nil
        refined.carouselImageURLs = []
        refined.imageURL = article.sourceFields["hatena:imageurl"].flatMap { $0.isEmpty ? nil : $0 }
        if refined.author == nil, let count = article.sourceFields["hatena:bookmarkcount"], !count.isEmpty {
            refined.author = "\(count) users"
        }
        return refined
    }
}
