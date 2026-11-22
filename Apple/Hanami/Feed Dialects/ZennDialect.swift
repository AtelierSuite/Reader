import Foundation

nonisolated enum ZennDialect: FeedDialect {

    static func matches(feedURL: URL, feed _: ParsedFeed) -> Bool {
        feedURL.host?.lowercased() == "zenn.dev"
    }

    /// Zenn flattens Markdown into the description, leaving a lone "!" for each message box and indented headings.
    static func refine(_ article: ParsedArticle, feedURL _: URL) -> ParsedArticle {
        guard let summary = article.summary else { return article }
        var refined = article
        let lines = summary.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != "!" }
        refined.summary = lines.isEmpty ? nil : lines.joined(separator: "\n")
        return refined
    }
}
