import Foundation
import SwiftSoup

/// Rewrites Hatena Blog's footnotes and Amazon product blocks into markup the viewer shows cleanly.
nonisolated enum HatenaBlogMarkup {

    static func refined(_ html: String) -> String {
        guard html.contains("footnote") || html.contains("hatena-asin-detail"),
              let document = try? SwiftSoup.parseBodyFragment(html), let body = document.body() else { return html }
        document.outputSettings().prettyPrint(pretty: false)
        rewriteFootnoteReferences(in: body)
        rewriteFootnotes(in: body)
        rewriteProductBlocks(in: body)
        return (try? body.html()) ?? html
    }

    /// `<a href="#f-…" title="note text">*1</a>` links to an anchor that does not exist outside the blog.
    private static func rewriteFootnoteReferences(in body: Element) {
        for reference in (try? body.select("a[href^=#f-]").array()) ?? [] {
            let marker = RSSParser.escapeXMLText((try? reference.text()) ?? "")
            _ = try? reference.before("<sup>\(marker)</sup>")
            _ = try? reference.remove()
        }
    }

    private static func rewriteFootnotes(in body: Element) {
        for block in (try? body.select("div.footnote").array()) ?? [] {
            var notes = "<hr>"
            for note in (try? block.select("p.footnote").array()) ?? [] {
                let marker = RSSParser.escapeXMLText((try? note.select(".footnote-number").text()) ?? "")
                let text = (try? note.select(".footnote-text").html()) ?? ""
                guard !text.isEmpty else { continue }
                notes += "<p><sup>\(marker)</sup> \(text)</p>"
            }
            _ = try? block.before(notes)
            _ = try? block.remove()
        }
    }

    private static func rewriteProductBlocks(in body: Element) {
        for block in (try? body.select("div.hatena-asin-detail").array()) ?? [] {
            guard let link = try? block.select(".hatena-asin-detail-title a").first(),
                  let title = try? link.text(), !title.isEmpty else {
                _ = try? block.remove()
                continue
            }
            let address = RSSParser.escapeXMLAttribute((try? link.attr("href")) ?? "")
            let details = ((try? block.select(".hatena-asin-detail-meta li").array()) ?? [])
                .compactMap { try? $0.text() }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            var product = "<blockquote><p><a href=\"\(address)\">\(RSSParser.escapeXMLText(title))</a></p>"
            if !details.isEmpty { product += "<p>\(RSSParser.escapeXMLText(details))</p>" }
            _ = try? block.before(product + "</blockquote>")
            _ = try? block.remove()
        }
    }
}
