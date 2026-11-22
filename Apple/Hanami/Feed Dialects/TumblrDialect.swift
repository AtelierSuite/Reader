import Foundation
import SwiftSoup

nonisolated enum TumblrDialect: FeedDialect {

    static let placeholderTitles: Set<String> = [
        "", "photo", "photoset", "video", "audio", "source", "link", "quote", "chat", "answer", "no title"
    ]

    static func matches(feedURL: URL, feed: ParsedFeed) -> Bool {
        let host = feedURL.host?.lowercased() ?? ""
        return host.hasSuffix(".tumblr.com") || feed.generator?.hasPrefix("Tumblr") == true
    }

    static func refine(_ article: ParsedArticle, feedURL _: URL) -> ParsedArticle {
        guard let description = article.descriptionHTML, !description.isEmpty else { return article }
        var refined = article
        let body = TumblrReblogTrail.flattened(description)
        refined.content = body
        let ownWords = TumblrReblogTrail.withoutAttribution(body)
        refined.summary = FeedDialectText.summary(fromHTML: ownWords, baseURL: URL(string: article.url))
        let text = FeedDialectText.plainText(fromHTML: ownWords)
        if !hasHeading(article.title, in: ownWords), isGeneratedTitle(article.title, bodyText: text),
           let postTitle = FeedDialectText.postTitle(from: text) {
            refined.title = postTitle
        }
        let images = FeedDialectText.imageURLs(inHTML: description)
        if images.count > 1 {
            refined.carouselImageURLs = Array(images.prefix(RSSParser.maximumMediaImageCount))
        }
        if let firstImage = images.first {
            refined.imageURL = firstImage
        } else if refined.imageURL == nil {
            refined.imageURL = videoPoster(in: description)
        }
        return refined
    }

    /// Tumblr fills `<title>` with the start of the post or a post-type word when the author gave none.
    static func isGeneratedTitle(_ title: String, bodyText: String) -> Bool {
        let normalizedTitle = normalized(title)
        if placeholderTitles.contains(normalizedTitle) || title.contains(":\n") { return true }
        let stem = normalizedTitle.replacingOccurrences(of: "…", with: "").replacingOccurrences(of: "...", with: "")
        guard !stem.isEmpty else { return true }
        return normalized(String(bodyText.prefix(400))).contains(stem)
    }

    private static func hasHeading(_ title: String, in html: String) -> Bool {
        guard let headings = try? SwiftSoup.parseBodyFragment(html).select("h1, h2") else { return false }
        return headings.contains { normalized((try? $0.text()) ?? "") == normalized(title) }
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func videoPoster(in html: String) -> String? {
        guard let poster = try? SwiftSoup.parseBodyFragment(html).select("video[poster]").first()?.attr("poster"),
              !poster.isEmpty else { return nil }
        return poster
    }
}
