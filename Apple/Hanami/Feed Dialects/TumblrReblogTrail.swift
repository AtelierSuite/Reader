import Foundation
import SwiftSoup

/// Tumblr nests each reblog as `<p><a class="tumblr_blog">name</a>:</p><blockquote>…</blockquote>`.
nonisolated enum TumblrReblogTrail {

    static let attributionClass = "reblog-attribution"

    /// Unnests the trail into one run of posts, oldest first, each under its author's name.
    static func flattened(_ html: String) -> String {
        guard html.contains("tumblr_blog"),
              let document = try? SwiftSoup.parseBodyFragment(html),
              let body = document.body() else { return html }
        document.outputSettings().prettyPrint(pretty: false)
        return flattened(body.children().array()).joined()
    }

    static func withoutAttribution(_ html: String) -> String {
        guard let document = try? SwiftSoup.parseBodyFragment(html) else { return html }
        _ = try? document.select("p.\(attributionClass)").remove()
        return (try? document.body()?.html()) ?? html
    }

    private static func flattened(_ elements: [Element]) -> [String] {
        var pieces: [String] = []
        var index = 0
        while index < elements.count {
            let element = elements[index]
            if let blog = blogLink(element), index + 1 < elements.count,
               elements[index + 1].tagName().lowercased() == "blockquote" {
                pieces.append(contentsOf: flattenedReblog(of: blog, quote: elements[index + 1]))
                index += 2
            } else {
                pieces.append((try? element.outerHtml()) ?? "")
                index += 1
            }
        }
        return pieces
    }

    private static func flattenedReblog(of blog: (name: String, href: String), quote: Element) -> [String] {
        let inner = quote.children().array()
        let link = "<a href=\"\(FeedDialectText.escaped(blog.href))\">\(FeedDialectText.escaped(blog.name))</a>"
        guard !inner.isEmpty else {
            return [attribution(link, isOriginalPost: true), "<p>\((try? quote.html()) ?? "")</p>"]
        }
        let startsWithReblog = inner.count >= 2 && blogLink(inner[0]) != nil
            && inner[1].tagName().lowercased() == "blockquote"
        if startsWithReblog {
            return flattened(Array(inner.prefix(2))) + [attribution(link, isOriginalPost: false)]
                + inner.dropFirst(2).map { (try? $0.outerHtml()) ?? "" }
        }
        return [attribution(link, isOriginalPost: true)] + inner.map { (try? $0.outerHtml()) ?? "" }
    }

    /// The post at the start of the trail reads "Reblogged from name"; later additions carry only the name.
    private static func attribution(_ link: String, isOriginalPost: Bool) -> String {
        guard isOriginalPost else {
            return "<p class=\"\(attributionClass)\"><strong>\(link)</strong></p>"
        }
        let placeholder = "\u{FFFC}"
        let heading = String(localized: "Tumblr.RebloggedFrom \(placeholder)", table: "Feeds")
        let label = FeedDialectText.escaped(heading).replacingOccurrences(of: placeholder, with: link)
        return "<p class=\"\(attributionClass)\"><em>\(label)</em></p>"
    }

    private static func blogLink(_ element: Element) -> (name: String, href: String)? {
        guard element.tagName().lowercased() == "p",
              let link = try? element.select("a.tumblr_blog").first(),
              let name = try? link.text(), !name.isEmpty else { return nil }
        return (name, (try? link.attr("href")) ?? "")
    }
}
