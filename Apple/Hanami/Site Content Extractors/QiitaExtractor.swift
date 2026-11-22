import Foundation
import SwiftSoup

public nonisolated struct QiitaExtractor: SiteContentExtractor {

    public func canHandle(url: URL) -> Bool {
        matchesHost(url, ["qiita.com"]) && url.pathComponents.contains("items")
    }

    public func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        guard let container = try? document.select(".it-MdContent, .mdContent-inner").first() else {
            return nil
        }
        let html = (try? container.outerHtml()) ?? ""
        guard !html.isEmpty else { return nil }

        let text = HTMLContentExtractor.extractText(
            fromHTML: html,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        let metadata = HTMLContentExtractor.extractMetadata(from: document)
        return ExtractionResult(text: text, metadata: metadata)
    }
}
