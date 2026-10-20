import Foundation
import SwiftSoup

public nonisolated struct SlashdotExtractor: SiteContentExtractor {

    public func canHandle(url: URL) -> Bool {
        matchesHost(url, ["slashdot.org"])
    }

    public func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        guard let body = try? document.select("article.fhitem-story .body > div[id^=text-]").first(),
              let html = paragraphedHTML(of: body, in: document) else {
            return nil
        }

        let text = HTMLContentExtractor.extractText(
            fromHTML: html,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        var metadata = HTMLContentExtractor.extractMetadata(from: document)
        if metadata.leadImageURL?.contains("/sd/topics/") == true {
            metadata.leadImageURL = nil
        }
        if metadata.author == nil,
           let author = try? document.select("article.fhitem-story .story-byline a").first()?.text(),
           !author.isEmpty {
            metadata.author = author
        }
        return ExtractionResult(text: text, metadata: metadata)
    }

    /// Stories are bare text split by `<br><br>`, and SwiftSoup's pretty printer breaks lines
    /// before inline tags in a `<div>`, which the extractor then keeps as line breaks.
    private func paragraphedHTML(of body: Element, in document: Document) -> String? {
        document.outputSettings().prettyPrint(pretty: false)
        defer { document.outputSettings().prettyPrint(pretty: true) }
        guard let innerHTML = try? body.html() else { return nil }
        let paragraphs = innerHTML
            .split(separator: #/<br\s*/?>(?:\s*<br\s*/?>)+/#)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !paragraphs.isEmpty else { return nil }
        return "<div>" + paragraphs.map { "<p>\($0)</p>" }.joined() + "</div>"
    }
}
