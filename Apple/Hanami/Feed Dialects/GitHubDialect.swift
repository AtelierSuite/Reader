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
        if article.imageURL?.contains("githubassets.com/images/icons") == true {
            refined.imageURL = nil
        }
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

    static func enrich(_ feed: ParsedFeed, feedURL: URL, feedID: Int64) async -> ParsedFeed {
        guard let repositoryPath = GitHubReleases.repositoryPath(fromFeedURL: feedURL) else { return feed }
        let releases = await GitHubReleases.fetch(repositoryPath: repositoryPath)
        guard !releases.isEmpty else { return feed }
        let hidesPrereleases = UserDefaults.standard.bool(forKey: GitHubReleases.hidesPrereleasesKey(forFeedID: feedID))
        var enriched = feed
        enriched.articles = feed.articles.compactMap { article in
            guard let release = GitHubReleases.tagName(fromReleaseURL: article.url).flatMap({ releases[$0] }) else {
                return article
            }
            if release.prerelease, hidesPrereleases { return nil }
            var detailed = article
            if release.prerelease {
                detailed.title += " (\(String(localized: "GitHub.Prerelease", table: "Feeds")))"
            }
            let assets = GitHubReleases.assetsHTML(for: release.assets)
            if !assets.isEmpty { detailed.content = (article.content ?? "") + assets }
            return detailed
        }
        return enriched
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
