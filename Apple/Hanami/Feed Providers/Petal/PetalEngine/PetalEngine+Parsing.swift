import Foundation
import SwiftSoup

public nonisolated extension PetalEngine {

    // MARK: - Parsing

    /// Runs the recipe's selectors against the given HTML.
    static func parse(html: String, recipe: PetalRecipe) -> [ParsedArticle] {
        let base = URL(string: recipe.baseURL ?? recipe.siteURL)
        do {
            let document = try SwiftSoup.parse(html, recipe.siteURL)
            let items = try document.select(recipe.itemSelector)
            var articles: [ParsedArticle] = []
            articles.reserveCapacity(min(items.count, recipe.maxItems))
            var seenURLs = Set<String>()

            for item in items {
                guard articles.count < recipe.maxItems else { break }
                if let parsed = parseItem(item, recipe: recipe, baseURL: base),
                   seenURLs.insert(parsed.url).inserted {
                    articles.append(parsed)
                }
            }
            return articles
        } catch {
            return []
        }
    }

    private static func parseItem(
        _ item: Element,
        recipe: PetalRecipe,
        baseURL: URL?
    ) -> ParsedArticle? {
        guard let linkString = extractLink(item: item, recipe: recipe),
              let resolvedURL = resolveURL(linkString, base: baseURL) else {
            return nil
        }

        let title = extractText(
            item: item, selector: recipe.titleSelector, fallbackOwnText: true
        )
        guard !title.isEmpty else { return nil }

        let summary = extractText(
            item: item, selector: recipe.summarySelector, fallbackOwnText: false
        )
        let author = extractText(
            item: item, selector: recipe.authorSelector, fallbackOwnText: false
        )
        let image = extractImage(item: item, recipe: recipe, baseURL: baseURL)
        let date = extractDate(item: item, recipe: recipe)

        return ParsedArticle(
            title: title,
            url: resolvedURL,
            author: author.isEmpty ? nil : author,
            summary: summary.isEmpty ? nil : summary,
            content: nil,
            imageURL: image,
            publishedDate: date,
            audioURL: nil,
            duration: nil
        )
    }

    // MARK: - Field extractors

    static func extractLink(
        item: Element,
        recipe: PetalRecipe
    ) -> String? {
        if let selector = recipe.linkSelector,
           let element = try? item.select(selector).first(),
           let value = try? element.attr(recipe.linkAttribute),
           !value.isEmpty {
            return value
        }
        if let anchor = try? item.select("a[href]").first(),
           let href = try? anchor.attr("href"), !href.isEmpty {
            return href
        }
        return nil
    }

    static func extractText(
        item: Element,
        selector: String?,
        fallbackOwnText: Bool
    ) -> String {
        if let selector, !selector.isEmpty,
           let element = try? item.select(selector).first() {
            if let text = try? element.text() {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if fallbackOwnText, let text = try? item.text() {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private static func extractImage(
        item: Element,
        recipe: PetalRecipe,
        baseURL: URL?
    ) -> String? {
        if let selector = recipe.imageSelector, !selector.isEmpty {
            guard let element = try? item.select(selector).first(),
                  let value = imageSource(of: element, preferring: recipe.imageAttribute) else { return nil }
            return resolveURL(value, base: baseURL)
        }
        for image in (try? item.select("img").array()) ?? [] {
            if let value = imageSource(of: image, preferring: "src") {
                return resolveURL(value, base: baseURL)
            }
        }
        return nil
    }

    static let lazyImageAttributes = ["data-src", "data-original", "data-lazy-src", "data-srcset", "srcset"]

    /// Lazy-loading pages keep a placeholder in `src` and the real address in another attribute.
    private static func imageSource(of element: Element, preferring attribute: String) -> String? {
        for name in [attribute] + lazyImageAttributes {
            guard let raw = try? element.attr(name) else { continue }
            let candidate = name.hasSuffix("srcset") ? largestSourceSetURL(raw) : raw
            let value = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty, !value.lowercased().hasPrefix("data:") {
                return value
            }
        }
        return nil
    }

    private static func largestSourceSetURL(_ sourceSet: String) -> String {
        let candidates = sourceSet.split(separator: ",").compactMap { entry -> (url: String, size: Double)? in
            let parts = entry.split(whereSeparator: \.isWhitespace)
            guard let url = parts.first else { return nil }
            let size = parts.dropFirst().first.flatMap { Double($0.dropLast()) } ?? 0
            return (String(url), size)
        }
        return candidates.max { $0.size < $1.size }?.url ?? ""
    }

    private static func extractDate(
        item: Element,
        recipe: PetalRecipe
    ) -> Date? {
        guard let raw = rawDateText(item: item, recipe: recipe) else { return nil }
        return parseFlexibleDate(raw)
    }

    static func rawDateText(item: Element, recipe: PetalRecipe) -> String? {
        guard let selector = recipe.dateSelector, !selector.isEmpty,
              let element = try? item.select(selector).first() else {
            return nil
        }
        let raw: String
        if let attribute = recipe.dateAttribute, !attribute.isEmpty {
            raw = (try? element.attr(attribute)) ?? ""
        } else {
            raw = (try? element.text()) ?? ""
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - URL resolution

    /// Resolves a potentially relative URL against a base.
    static func resolveURL(_ href: String, base: URL?) -> String? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        if trimmed.hasPrefix("//") {
            return "https:\(trimmed)"
        }
        guard let base else { return nil }
        return URL(string: trimmed, relativeTo: base)?.absoluteString
    }
}
