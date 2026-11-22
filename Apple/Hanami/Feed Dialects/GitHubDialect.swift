import Foundation

nonisolated enum GitHubDialect: FeedDialect {

    nonisolated(unsafe) private static let expiringImageRegex =
        /https:\/\/private-user-images\.githubusercontent\.com\/\d+\/\d+-([0-9a-fA-F\-]{36})\.[A-Za-z0-9]+\?jwt=[^"'\s<>]+/

    nonisolated(unsafe) private static let commitMessageRegex =
        /^\s*<pre[^>]*>(.*)<\/pre>\s*$/.dotMatchesNewlines()

    static func matches(feedURL: URL, feed _: ParsedFeed) -> Bool {
        feedURL.host?.lowercased() == "github.com"
    }

    static func refine(_ article: ParsedArticle, feedURL _: URL) -> ParsedArticle {
        var refined = article
        guard var content = article.content else { return refined }
        if content == "<p>No content.</p>" {
            refined.content = nil
            return refined
        }
        content = withLastingImageURLs(content)
        refined.content = content
        if article.url.contains("/commit/"), let match = content.firstMatch(of: commitMessageRegex) {
            applyCommitMessage(RSSParser.decodeHTMLEntities(String(match.1)), to: &refined)
        }
        return refined
    }

    /// Attachment links in the feed carry a token that expires in five minutes; this address redirects to a fresh one.
    static func withLastingImageURLs(_ html: String) -> String {
        html.replacing(expiringImageRegex) { match in
            "https://github.com/user-attachments/assets/\(match.1)"
        }
    }

    private static func applyCommitMessage(_ message: String, to article: inout ParsedArticle) {
        let lines = message.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        guard let subject = lines.first, !subject.isEmpty else { return }
        let body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        article.title = subject
        article.content = body.isEmpty ? nil : RSSParser.paragraphHTML(fromPlainText: body)
        article.summary = body.isEmpty ? nil : body
    }
}
