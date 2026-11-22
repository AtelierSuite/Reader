import Foundation

/// Runs a `PetalRecipe` against its source page and emits `ParsedArticle` values.
public nonisolated enum PetalEngine {

    public struct PreviewResult: Sendable {
        public var articles: [ParsedArticle]
        public var fetchedHTMLSample: String?
        public var errorMessage: String?
    }

    // MARK: - Public API

    /// Runs the recipe and returns a preview with an HTML sample for selector debugging.
    public static func preview(
        for recipe: PetalRecipe,
        pageURL overrideURL: String? = nil
    ) async -> PreviewResult {
        guard let html = await fetchHTML(for: recipe, pageURL: overrideURL) else {
            return PreviewResult(
                articles: [],
                fetchedHTMLSample: nil,
                errorMessage: String(localized: "Error.FetchFailed", table: "Petal")
            )
        }
        let articles = parse(html: html, recipe: recipe)
        return PreviewResult(
            articles: articles,
            fetchedHTMLSample: html,
            errorMessage: articles.isEmpty
                ? String(localized: "Error.NoMatches", table: "Petal") : nil
        )
    }
}
