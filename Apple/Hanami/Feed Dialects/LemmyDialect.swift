import Foundation

nonisolated enum LemmyDialect: FeedDialect {

    static let linkClass = "lemmy-link"

    nonisolated(unsafe) private static let boilerplateRegex =
        /^submitted by <a [^>]*>[^<]*<\/a> to <a [^>]*>[^<]*<\/a><br\s*\/?>-?\d+ points \| <a [^>]*>\d+ comments<\/a>(?:<br\s*\/?><a href="([^"]*)">[^<]*<\/a>)?/

    /// `/feeds/c/<community>.xml`, `/feeds/u/<user>.xml` and `/feeds/front.xml`.
    static func isFeedURL(_ url: URL) -> Bool {
        let components = url.pathComponents
        guard components.count >= 3, components[1] == "feeds", url.path.hasSuffix(".xml") else { return false }
        return components.count == 3 ? components[2] == "front.xml" : ["c", "u"].contains(components[2])
    }

    static func matches(feedURL: URL, feed: ParsedFeed) -> Bool {
        isFeedURL(feedURL) && feed.articles.contains { $0.descriptionHTML?.hasPrefix("submitted by") == true }
    }

    static func refine(_ article: ParsedArticle, feedURL _: URL) -> ParsedArticle {
        var refined = article
        refined.usesPageImage = false
        refined.author = article.author.map(handle(fromActorURL:))
        refined.carouselImageURLs = []
        guard let description = article.descriptionHTML,
              let match = description.firstMatch(of: boilerplateRegex) else { return refined }
        let body = String(description[match.range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let linkedPage = article.sourceFields[RSSParser.linkedPageSourceField] ?? match.1.map(String.init)
        var content = body
        if let linkedPage, !linkedPage.isEmpty, linkedPage != article.url {
            content = linkParagraph(for: linkedPage) + body
        }
        refined.content = content.isEmpty ? nil : content
        refined.summary = body.isEmpty
            ? linkedPage.flatMap { URL(string: $0)?.host }
            : FeedDialectText.summary(fromHTML: body, baseURL: URL(string: article.url))
        return refined
    }

    static func linkParagraph(for linkedPage: String) -> String {
        let escaped = FeedDialectText.escaped(linkedPage)
        return "<p class=\"\(linkClass)\"><a href=\"\(escaped)\">\(escaped)</a></p>"
    }

    /// The page a link post points at, when the post has no text of its own to show instead.
    static func linkedPageURL(inContent content: String) -> URL? {
        let prefix = "<p class=\"\(linkClass)\"><a href=\""
        guard content.hasPrefix(prefix), content.hasSuffix("</a></p>"),
              content.components(separatedBy: "</p>").count == 2,
              let end = content[content.index(content.startIndex, offsetBy: prefix.count)...].firstIndex(of: "\"")
        else { return nil }
        let start = content.index(content.startIndex, offsetBy: prefix.count)
        return URL(string: RSSParser.decodeHTMLEntities(String(content[start..<end])))
    }

    /// `https://piefed.zip/u/inari` reads as `inari@piefed.zip`.
    static func handle(fromActorURL author: String) -> String {
        guard let url = URL(string: author), let host = url.host,
              url.pathComponents.count == 3, url.pathComponents[1] == "u" else { return author }
        return "\(url.pathComponents[2])@\(host)"
    }
}
