import Foundation
import FoundationModels

@Generable
nonisolated struct PetalAgentRecipe: Sendable, Equatable {
    @Guide(description: "CSS selector matching each entry on the page.")
    var itemSelector: String
    @Guide(description: "Selector inside an item for the headline. Empty if none.")
    var titleSelector: String
    @Guide(description: "Selector inside an item for the link. Empty when the item itself is the link.")
    var linkSelector: String
    @Guide(description: "Selector inside an item for a short description. Empty if none.")
    var summarySelector: String
    @Guide(description: "Selector inside an item for the image. Empty if none.")
    var imageSelector: String
    @Guide(description: "Selector inside an item for the publication date. Empty if none.")
    var dateSelector: String
    @Guide(description: "Attribute holding the date, such as datetime. Empty to use the element's text.")
    var dateAttribute: String
    @Guide(description: "Selector inside an item for the author name. Empty if none.")
    var authorSelector: String

    func recipe(name: String, siteURL: String) -> PetalRecipe {
        PetalRecipe(
            name: name,
            siteURL: siteURL,
            itemSelector: itemSelector.trimmingCharacters(in: .whitespacesAndNewlines),
            titleSelector: Self.optional(titleSelector),
            linkSelector: Self.optional(linkSelector),
            summarySelector: Self.optional(summarySelector),
            imageSelector: Self.optional(imageSelector),
            dateSelector: Self.optional(dateSelector),
            dateAttribute: Self.optional(dateAttribute),
            authorSelector: Self.optional(authorSelector)
        )
    }

    private static func optional(_ selector: String) -> String? {
        let trimmed = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
