import Foundation
import SwiftSoup

public nonisolated struct TechCrunchExtractor: SiteContentExtractor {

    public func canHandle(url: URL) -> Bool {
        matchesHost(url, ["techcrunch.com"])
    }

    public func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        guard let body = try? document.select("div.entry-content.wp-block-post-content").first() else {
            return nil
        }
        try? body.select(".ad-unit, .tc-event-inline-cta, .jw-player-inline-promo").remove()

        guard let html = try? body.outerHtml(), !html.isEmpty else { return nil }

        let text = HTMLContentExtractor.extractText(
            fromHTML: html,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        guard text?.isEmpty == false else { return nil }
        let metadata = HTMLContentExtractor.extractMetadata(from: document)
        return ExtractionResult(text: text, metadata: metadata)
    }
}
