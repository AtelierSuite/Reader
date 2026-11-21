import Foundation
import FoundationModels

nonisolated struct PetalTestRecipeTool: Tool {
    let name = "testRecipe"
    let description = "Runs a recipe against the page and reports the entries it extracts and which fields are empty."
    let workspace: PetalAgentWorkspace

    func call(arguments: PetalAgentRecipe) async throws -> String {
        var articles: [ParsedArticle] = []
        let report = workspace.perform(.testingFeed) { _ in
            let recipe = arguments.recipe(name: workspace.pageTitle, siteURL: workspace.siteURL)
            articles = PetalEngine.parse(html: workspace.html, recipe: recipe)
            return Self.report(for: articles)
        }
        workspace.recordTest(of: arguments, articles: articles)
        return report
    }

    private static func report(for articles: [ParsedArticle]) -> String {
        guard !articles.isEmpty else {
            return "0 entries extracted. The item selector matched nothing usable, "
                + "or no item produced both a title and a link."
        }
        var lines = ["\(articles.count) entries extracted."]
        let missing: [(field: String, count: Int)] = [
            ("summary", articles.filter { $0.summary == nil }.count),
            ("image", articles.filter { $0.imageURL == nil }.count),
            ("date", articles.filter { $0.publishedDate == nil }.count),
            ("author", articles.filter { $0.author == nil }.count)
        ]
        for entry in missing where entry.count > 0 {
            lines.append("\(entry.field) is empty in \(entry.count) of \(articles.count) entries.")
        }
        let titles = Set(articles.map(\.title))
        if titles.count < articles.count {
            lines.append("\(articles.count - titles.count) entries share a title with another entry.")
        }
        for article in articles.prefix(3) {
            let date = article.publishedDate.map { ISO8601DateFormatter().string(from: $0) } ?? "none"
            lines.append("""
                - title: \(article.title.prefix(100))
                  link: \(article.url)
                  date: \(date)
                  image: \(article.imageURL ?? "none")
                  summary: \(article.summary.map { String($0.prefix(100)) } ?? "none")
                """)
        }
        return lines.joined(separator: "\n")
    }
}
