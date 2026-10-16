import Foundation
import SwiftSoup

public nonisolated struct VergeExtractor: SiteContentExtractor {

    public func canHandle(url: URL) -> Bool {
        matchesHost(url, ["theverge.com"])
    }

    public func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        guard let container = try? document.select("#zephr-anchor").first() else { return nil }
        removeNonBodyChildren(of: container)
        guard let html = try? container.outerHtml(),
              !html.isEmpty else { return nil }

        let text = HTMLContentExtractor.extractText(
            fromHTML: html,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        let metadata = HTMLContentExtractor.extractMetadata(from: document)
        return ExtractionResult(text: text, metadata: metadata)
    }

    /// Follow-topic footers and author popovers sit beside the body blocks under hashed class names.
    private func removeNonBodyChildren(of container: Element) {
        let bodyClass = "duet--article--article-body-component"
        let children = container.children().array()
        guard children.contains(where: { $0.hasClass(bodyClass) }) else { return }
        for child in children where !child.hasClass(bodyClass) {
            try? child.remove()
        }
    }
}
