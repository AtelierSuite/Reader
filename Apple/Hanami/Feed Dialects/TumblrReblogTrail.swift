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
        let elements = body.children().array()
        guard let source = elements.first.flatMap(blogLink) else { return html }
        let heading = String(localized: "Tumblr.RebloggedFrom \(source.name)", table: "Feeds")
        let header = "<p class=\"\(attributionClass)\"><em>\(FeedDialectText.escaped(heading))</em></p>"
        return header + flattened(elements).joined()
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
        let attribution = "<p class=\"\(attributionClass)\"><strong><a href=\""
            + "\(FeedDialectText.escaped(blog.href))\">\(FeedDialectText.escaped(blog.name))</a></strong></p>"
        guard !inner.isEmpty else {
            return [attribution, "<p>\((try? quote.html()) ?? "")</p>"]
        }
        let startsWithReblog = inner.count >= 2 && blogLink(inner[0]) != nil
            && inner[1].tagName().lowercased() == "blockquote"
        if startsWithReblog {
            return flattened(Array(inner.prefix(2))) + [attribution]
                + inner.dropFirst(2).map { (try? $0.outerHtml()) ?? "" }
        }
        return [attribution] + inner.map { (try? $0.outerHtml()) ?? "" }
    }

    private static func blogLink(_ element: Element) -> (name: String, href: String)? {
        guard element.tagName().lowercased() == "p",
              let link = try? element.select("a.tumblr_blog").first(),
              let name = try? link.text(), !name.isEmpty else { return nil }
        return (name, (try? link.attr("href")) ?? "")
    }
}
