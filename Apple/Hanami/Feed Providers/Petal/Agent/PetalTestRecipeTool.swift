import Foundation
import FoundationModels

nonisolated struct PetalTestRecipeTool: Tool {
    let name = "testRecipe"
    let description = "Runs a recipe against the page and reports the entries it extracts and which fields are empty."
    let workspace: PetalAgentWorkspace

    func call(arguments: PetalAgentRecipe) async throws -> String {
        var diagnosis = PetalRecipeDiagnosis()
        let report = try workspace.perform(.testingFeed) { _ in
            let recipe = arguments.recipe(name: workspace.pageTitle, siteURL: workspace.siteURL)
            diagnosis = PetalEngine.diagnose(html: workspace.html, recipe: recipe)
            return Self.report(for: diagnosis)
        }
        workspace.recordTest(of: arguments, articles: diagnosis.articles)
        return report
    }

    private static func report(for diagnosis: PetalRecipeDiagnosis) -> String {
        let articles = diagnosis.articles
        var lines = ["The item selector matches \(diagnosis.matchedItemCount) elements; "
            + "\(articles.count) entries extracted."]
        if diagnosis.itemsWithoutLink > 0 {
            lines.append("\(diagnosis.itemsWithoutLink) items have no link and were dropped.")
        }
        if diagnosis.itemsWithoutTitle > 0 {
            lines.append("\(diagnosis.itemsWithoutTitle) items have no title and were dropped.")
        }
        if diagnosis.repeatedLinkCount > 0 {
            lines.append("\(diagnosis.repeatedLinkCount) items repeat another item's link and were dropped; "
                + "the item selector may match parts of one entry, or the link selector a shared link.")
        }
        if !diagnosis.unreadableDates.isEmpty {
            let samples = diagnosis.unreadableDates.map { "\"\($0.prefix(40))\"" }.joined(separator: ", ")
            lines.append("The date selector matched text that is not a date: \(samples). "
                + "Pick the element or attribute holding the date, or leave the date empty.")
        }
        guard !articles.isEmpty else { return lines.joined(separator: "\n") }
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
                  image: \(article.imageURL.map { String($0.prefix(120)) } ?? "none")
                  summary: \(article.summary.map { String($0.prefix(100)) } ?? "none")
                  author: \(article.author.map { String($0.prefix(60)) } ?? "none")
                """)
        }
        return lines.joined(separator: "\n")
    }
}
