import Foundation
import SwiftSoup

nonisolated enum FeedDialectText {

    static let postTitleLength = 100

    static func plainText(fromHTML html: String) -> String {
        let text = (try? SwiftSoup.parseBodyFragment(html).text()) ?? RSSParser.stripHTMLTags(html)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Posts without a headline are titled with the start of their text, as the parser does for untitled entries.
    static func postTitle(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(postTitleLength))
    }

    static func summary(fromHTML html: String, baseURL: URL?) -> String? {
        RSSParser().cleanHTMLPreservingStructure(html, baseURL: baseURL)
    }

    static func escaped(_ text: String) -> String {
        RSSParser.escapeXMLAttribute(text)
    }

    static func imageURLs(inHTML html: String) -> [String] {
        guard let images = try? SwiftSoup.parseBodyFragment(html).select("img") else { return [] }
        var urls: [String] = []
        for image in images {
            let sourceSet = (try? image.attr("srcset")) ?? ""
            let source = largestSourceSetURL(sourceSet) ?? ((try? image.attr("src")) ?? "")
            if !source.isEmpty, !source.hasPrefix("data:"), !urls.contains(source) {
                urls.append(source)
            }
        }
        return urls
    }

    private static func largestSourceSetURL(_ sourceSet: String) -> String? {
        let candidates = sourceSet.split(separator: ",").compactMap { entry -> (url: String, width: Int)? in
            let parts = entry.split(whereSeparator: \.isWhitespace)
            guard parts.count == 2, parts[1].hasSuffix("w"), let width = Int(parts[1].dropLast()) else {
                return nil
            }
            return (String(parts[0]), width)
        }
        return candidates.max { $0.width < $1.width }?.url
    }
}
