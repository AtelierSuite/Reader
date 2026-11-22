import Foundation
import SwiftSoup

/// What a recipe does on a page beyond the entries it extracts, so a failing field can be told apart from a missing one.
nonisolated struct PetalRecipeDiagnosis: Sendable {
    var matchedItemCount = 0
    var itemsWithoutLink = 0
    var itemsWithoutTitle = 0
    var repeatedLinkCount = 0
    var unreadableDates: [String] = []
    var invalidSelectors: [String] = []
    var unmatchedSelectors: [String] = []
    var articles: [ParsedArticle] = []

    /// A title or link selector that fails silently falls back to the whole item, which reads as a working feed but is not one.
    var hasBrokenEssentials: Bool {
        let broken = invalidSelectors + unmatchedSelectors
        return broken.contains("item") || broken.contains("title") || broken.contains("link")
    }
}

nonisolated extension PetalEngine {

    static func diagnose(html: String, recipe: PetalRecipe) -> PetalRecipeDiagnosis {
        var diagnosis = PetalRecipeDiagnosis()
        diagnosis.articles = parse(html: html, recipe: recipe)
        guard let document = try? SwiftSoup.parse(html, recipe.siteURL) else { return diagnosis }
        guard let items = try? document.select(recipe.itemSelector) else {
            diagnosis.invalidSelectors.append("item")
            return diagnosis
        }
        checkFieldSelectors(of: recipe, in: items, into: &diagnosis)
        let base = URL(string: recipe.baseURL ?? recipe.siteURL)
        diagnosis.matchedItemCount = items.count
        var seenLinks = Set<String>()
        for item in items.array().prefix(recipe.maxItems) {
            let link = extractLink(item: item, recipe: recipe).flatMap { resolveURL($0, base: base) }
            if let link {
                if !seenLinks.insert(link).inserted { diagnosis.repeatedLinkCount += 1 }
            } else {
                diagnosis.itemsWithoutLink += 1
            }
            if extractText(item: item, selector: recipe.titleSelector, fallbackOwnText: true).isEmpty {
                diagnosis.itemsWithoutTitle += 1
            }
            if let rawDate = rawDateText(item: item, recipe: recipe), parseFlexibleDate(rawDate) == nil,
               diagnosis.unreadableDates.count < 3 {
                diagnosis.unreadableDates.append(rawDate)
            }
        }
        return diagnosis
    }

    private static func checkFieldSelectors(
        of recipe: PetalRecipe, in items: Elements, into diagnosis: inout PetalRecipeDiagnosis
    ) {
        let fields: [(name: String, selector: String?)] = [
            ("title", recipe.titleSelector), ("link", recipe.linkSelector),
            ("summary", recipe.summarySelector), ("image", recipe.imageSelector),
            ("date", recipe.dateSelector), ("author", recipe.authorSelector)
        ]
        for field in fields {
            guard let selector = field.selector, !selector.isEmpty else { continue }
            guard let matches = try? items.select(selector) else {
                diagnosis.invalidSelectors.append(field.name)
                continue
            }
            if matches.isEmpty() { diagnosis.unmatchedSelectors.append(field.name) }
        }
    }
}
