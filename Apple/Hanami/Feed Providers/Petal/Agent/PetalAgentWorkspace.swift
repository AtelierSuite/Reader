import Foundation
import SwiftSoup

/// The page an agent run works on. Tools reach it concurrently, so every access takes the lock.
nonisolated final class PetalAgentWorkspace: @unchecked Sendable {

    let html: String
    let siteURL: String
    let pageTitle: String
    private let document: Document
    private let onStep: @Sendable (PetalAgent.Step) -> Void
    private let lock = NSLock()
    private var toolCallCount = 0
    private var bestTest: (recipe: PetalAgentRecipe, score: Int)?
    private var testedRecipes: [PetalAgentRecipe] = []

    static let limitMessage = "Tool call limit reached. Answer with your best recipe now."

    init?(html: String, siteURL: String, onStep: @escaping @Sendable (PetalAgent.Step) -> Void) {
        guard let document = try? SwiftSoup.parse(html, siteURL) else { return nil }
        document.outputSettings().prettyPrint(pretty: false)
        _ = try? document.select("script, style, noscript, svg, template, link, meta, iframe").remove()
        self.html = html
        self.siteURL = siteURL
        self.document = document
        self.onStep = onStep
        let title = ((try? document.title()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        pageTitle = title.isEmpty ? (URL(string: siteURL)?.host ?? "Web Feed") : title
    }

    var bestTestedRecipe: PetalAgentRecipe? {
        lock.withLock { bestTest?.recipe }
    }

    /// Runs `work` against the page. Past the limit the model is told to answer, and stopped if it keeps calling.
    func perform(_ step: PetalAgent.Step, detail: String, _ work: (Document) -> String) throws -> String {
        onStep(step)
        let (callNumber, output) = lock.withLock {
            toolCallCount += 1
            let output = toolCallCount <= PetalAgent.toolCallLimit ? work(document) : Self.limitMessage
            return (toolCallCount, output)
        }
        log("WebFeedAgent", "tool call \(callNumber) \(step)(\(detail.prefix(120))): \(output.prefix(300))")
        guard callNumber <= PetalAgent.toolCallLimit + PetalAgent.toolCallGrace else {
            throw PetalAgent.Failure.toolCallLimitExceeded
        }
        return output
    }

    func hasTested(_ recipe: PetalAgentRecipe) -> Bool {
        lock.withLock { testedRecipes.contains(recipe) }
    }

    func recordTest(of recipe: PetalAgentRecipe, diagnosis: PetalRecipeDiagnosis) {
        lock.withLock {
            if !testedRecipes.contains(recipe) { testedRecipes.append(recipe) }
        }
        let score = Self.score(diagnosis)
        guard score > 0 else { return }
        lock.withLock {
            if score > (bestTest?.score ?? 0) {
                bestTest = (recipe, score)
            }
        }
    }

    /// Ranks how complete the entries are before how many there are, so a selector that sweeps in navigation links does not win.
    static func score(_ diagnosis: PetalRecipeDiagnosis) -> Int {
        let articles = diagnosis.articles
        guard isUsable(articles), !diagnosis.hasBrokenEssentials else { return 0 }
        let filledFields = articles.reduce(0) { total, article in
            total + (article.publishedDate == nil ? 0 : 1) + (article.imageURL == nil ? 0 : 1)
                + (article.summary == nil ? 0 : 1)
        }
        let completeness = Double(filledFields) / Double(articles.count * 3)
        return 1 + Int(completeness * 100) + min(articles.count, 30)
    }

    static func isUsable(_ articles: [ParsedArticle]) -> Bool {
        articles.count >= 2 && articles.allSatisfy { !$0.title.isEmpty && !$0.url.isEmpty }
    }

    /// A page whose list is drawn by scripts has almost no links in the HTML the server sends.
    static func looksUnrendered(html: String, siteURL: String) -> Bool {
        guard let document = try? SwiftSoup.parse(html, siteURL), let body = document.body() else { return true }
        _ = try? body.select("nav, header, footer, script, style, noscript").remove()
        return ((try? body.select("a[href]").count) ?? 0) < unrenderedLinkMinimum
    }

    static let unrenderedLinkMinimum = 8
}
