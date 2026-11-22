import Foundation
import SwiftSoup

nonisolated struct DLsiteDescriptionSection: Sendable {
    let heading: String?
    let html: String
}

nonisolated enum DLsiteDescription {

    private static let allowedTags: Set<String> = ["br", "b", "strong", "i", "em", "u", "span", "a", "img"]

    static func sections(fromWorkPageHTML html: String) -> [DLsiteDescriptionSection] {
        guard let document = try? SwiftSoup.parse(html, DLsiteProvider.origin),
              let sections = try? document.select("section.c-productContent") else { return [] }
        return sections.array().compactMap { section in
            let heading = (try? section.select(".headline__title").first()?.text())
                .flatMap { $0.isEmpty ? nil : $0 }
            let parts = ((try? section.select(".c-productContent__text, .c-productContent__image img").array()) ?? [])
                .compactMap(partHTML)
            guard !parts.isEmpty else { return nil }
            return DLsiteDescriptionSection(heading: heading, html: parts.joined())
        }
    }

    private static func partHTML(_ element: Element) -> String? {
        if element.tagName() == "img" {
            guard let source = DLsiteProvider.absoluteImageURL(try? element.attr("src")) else { return nil }
            return "<figure><img src=\"\(RSSParser.escapeXMLAttribute(source))\"></figure>"
        }
        guard let body = try? sanitizedHTML(of: element) else { return nil }
        let paragraphs = paragraphs(fromLineBrokenHTML: body)
        return paragraphs.isEmpty ? nil : paragraphs.map { "<p>\($0)</p>" }.joined()
    }

    static func paragraphs(fromLineBrokenHTML html: String) -> [String] {
        let lines = html
            .replacingOccurrences(of: #"\s*<br\s*/?>\s*"#, with: "\n", options: .regularExpression)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var paragraphs: [[String]] = [[]]
        for line in lines {
            if line.isEmpty {
                if !(paragraphs.last?.isEmpty ?? true) { paragraphs.append([]) }
            } else {
                paragraphs[paragraphs.count - 1].append(line)
            }
        }
        return paragraphs.filter { !$0.isEmpty }.map { $0.joined(separator: "<br>") }
    }

    private static func sanitizedHTML(of element: Element) throws -> String {
        for descendant in try element.select("*").array().reversed() where descendant !== element {
            if !allowedTags.contains(descendant.tagName()) {
                try descendant.unwrap()
            }
        }
        return try element.html()
    }
}
