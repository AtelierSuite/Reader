import Foundation
import SwiftSoup

nonisolated enum HatenaBlogDialect: FeedDialect {

    static let summaryLength = 300

    static func matches(feedURL _: URL, feed: ParsedFeed) -> Bool {
        feed.generator == "Hatena::Blog"
    }

    /// Hatena writes the summary from the rendered page, so text from link cards leaks into it.
    static func refine(_ article: ParsedArticle, feedURL _: URL) -> ParsedArticle {
        guard let content = article.content, let document = try? SwiftSoup.parseBodyFragment(content) else {
            return article
        }
        _ = try? document.select(
            "iframe, cite.hatena-citation, .hatena-asin-detail, div.footnote, a[href^=#f-], script, style"
        ).remove()
        let text = ((try? document.text()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var refined = article
        refined.content = HatenaBlogMarkup.refined(content)
        guard !text.isEmpty else { return refined }
        refined.summary = text.count > summaryLength ? String(text.prefix(summaryLength)) + "…" : text
        return refined
    }
}
