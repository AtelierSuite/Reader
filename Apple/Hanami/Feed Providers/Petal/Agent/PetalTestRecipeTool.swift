import Foundation
import FoundationModels

nonisolated struct PetalTestRecipeTool: Tool {
    let name = "testRecipe"
    let description = "Runs a recipe against the page and reports the entries it extracts and which fields are empty."
    let workspace: PetalAgentWorkspace

    func call(arguments: PetalAgentRecipe) async throws -> String {
        var diagnosis = PetalRecipeDiagnosis()
        let isRepeat = workspace.hasTested(arguments)
        let report = try workspace.perform(.testingFeed, detail: arguments.itemSelector) { _ in
            guard !isRepeat else { return Self.repeatMessage }
            let recipe = arguments.recipe(name: workspace.pageTitle, siteURL: workspace.siteURL)
            diagnosis = PetalEngine.diagnose(html: workspace.html, recipe: recipe)
            return Self.report(for: diagnosis)
        }
        if !isRepeat { workspace.recordTest(of: arguments, diagnosis: diagnosis) }
        return report
    }

    private static let repeatMessage = "You already tested this exact recipe and the result is the same. "
        + "Change a selector, or answer with your best recipe now."

    private static func report(for diagnosis: PetalRecipeDiagnosis) -> String {
        let articles = diagnosis.articles
        var lines = ["The item selector matches \(diagnosis.matchedItemCount) elements; "
            + "\(articles.count) entries extracted."]
        for field in diagnosis.invalidSelectors {
            lines.append("The \(field) selector is not valid CSS. Use only tag names and class names made of "
                + "letters, digits, - and _.")
        }
        for field in diagnosis.unmatchedSelectors {
            lines.append("The \(field) selector matches nothing inside the items; it is evaluated inside each item.")
        }
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
        if diagnosis.invalidSelectors.isEmpty, diagnosis.unmatchedSelectors.isEmpty,
           diagnosis.itemsWithoutLink == 0, diagnosis.itemsWithoutTitle == 0 {
            lines.append("Titles and links work. Answer with this recipe unless a field above can clearly be fixed.")
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
