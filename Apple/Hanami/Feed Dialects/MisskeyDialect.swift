import Foundation

nonisolated enum MisskeyDialect: FeedDialect {

    private static let customEmojiPattern =
        #"(?<![A-Za-z0-9]):(?=[A-Za-z0-9_+\-]*[A-Za-z_])[A-Za-z0-9_+\-]+(?:@[\w.\-]+)?:"#

    static func matches(feedURL _: URL, feed: ParsedFeed) -> Bool {
        feed.generator?.hasPrefix("Misskey") == true
    }

    static func refineFeedTitle(_ title: String) -> String {
        withoutCustomEmoji(title)
    }

    /// Misskey titles every note "New note by …" and puts a content warning in the description.
    static func refine(_ article: ParsedArticle, feedURL _: URL) -> ParsedArticle {
        var refined = article
        let note = withoutCustomEmoji(article.content ?? article.descriptionHTML ?? "")
        let noteText = FeedDialectText.plainText(fromHTML: note)
        let warning = article.content == nil ? nil : article.descriptionHTML
            .map { withoutCustomEmoji(FeedDialectText.plainText(fromHTML: $0)) }
            .flatMap { $0.isEmpty || $0 == noteText ? nil : $0 }
        if let warning {
            let label = "CW: \(warning)"
            refined.title = String(label.prefix(FeedDialectText.postTitleLength))
            refined.summary = label
            refined.content = "<p><strong>\(FeedDialectText.escaped(label))</strong></p><hr>" + note
        } else {
            refined.title = FeedDialectText.postTitle(from: noteText) ?? withoutCustomEmoji(article.title)
            refined.summary = FeedDialectText.summary(fromHTML: note, baseURL: URL(string: article.url))
            refined.content = note.isEmpty ? nil : note
        }
        return refined
    }

    static func withoutCustomEmoji(_ text: String) -> String {
        text.replacingOccurrences(of: customEmojiPattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
