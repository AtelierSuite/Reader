import Foundation
import SwiftSoup

/// What a recipe does on a page beyond the entries it extracts, so a failing field can be told apart from a missing one.
nonisolated struct PetalRecipeDiagnosis: Sendable {
    var matchedItemCount = 0
    var itemsWithoutLink = 0
    var itemsWithoutTitle = 0
    var repeatedLinkCount = 0
    var unreadableDates: [String] = []
    var articles: [ParsedArticle] = []
}

nonisolated extension PetalEngine {

    static func diagnose(html: String, recipe: PetalRecipe) -> PetalRecipeDiagnosis {
        var diagnosis = PetalRecipeDiagnosis()
        diagnosis.articles = parse(html: html, recipe: recipe)
        guard let document = try? SwiftSoup.parse(html, recipe.siteURL),
              let items = try? document.select(recipe.itemSelector) else { return diagnosis }
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
}
