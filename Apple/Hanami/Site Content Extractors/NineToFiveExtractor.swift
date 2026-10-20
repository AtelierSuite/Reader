import Foundation
import SwiftSoup

public nonisolated struct NineToFiveExtractor: SiteContentExtractor {

    public func canHandle(url: URL) -> Bool {
        matchesHost(url, ["9to5mac.com", "9to5google.com"])
    }

    public func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        let metadata = HTMLContentExtractor.extractMetadata(from: document)

        guard let container = try? document.select("div.post-content").first() else {
            return nil
        }
        // Every <article> here is a recirculation card, so strip the featured /
        // related modules in case they nest inside the body container.
        try? container.select(".featured-items, .related-guides, .related-guide").remove()
        try? container.select(
            ".outbrain-ad-label, .ad-disclaimer-container, .google-preferred-source-badge, #after_disclaimer_placement"
        ).remove()
        removeLinkListSections(from: container)
        removeFollowParagraphs(from: container)

        guard let html = try? container.outerHtml(), !html.isEmpty else { return nil }

        let text = HTMLContentExtractor.extractText(
            fromHTML: html,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        guard text?.isEmpty == false else { return nil }
        return ExtractionResult(text: text, metadata: metadata)
    }

    /// "More on Samsung:" and "Best iPhone accessories" are headings over lists of bare links.
    private func removeLinkListSections(from container: Element) {
        let headings = container.children().array().filter { ["h2", "h3"].contains($0.tagName()) }
        for heading in headings {
            guard let list = try? heading.nextElementSibling(),
                  list.tagName() == "ul",
                  case let items = list.children().array().filter({ $0.tagName() == "li" }),
                  !items.isEmpty,
                  items.allSatisfy(isBareLink) else { continue }
            try? list.remove()
            try? heading.remove()
        }
    }

    private func isBareLink(_ item: Element) -> Bool {
        guard let itemText = try? item.text(),
              let linkText = try? item.select("a").text() else { return false }
        return !itemText.isEmpty && itemText == linkText
    }

    private func removeFollowParagraphs(from container: Element) {
        let paragraphs = container.children().array().filter { $0.tagName() == "p" }
        for paragraph in paragraphs {
            guard let text = try? paragraph.text(),
                  text.hasPrefix("Follow "),
                  let label = text.split(separator: ":").first,
                  label.count < 40,
                  let linkText = try? paragraph.select("a").text(),
                  linkText.count * 2 >= text.count - label.count else { continue }
            try? paragraph.remove()
        }
    }
}
