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

    /// Runs `work` against the page unless the run has used up its tool calls.
    func perform(_ step: PetalAgent.Step, _ work: (Document) -> String) -> String {
        onStep(step)
        return lock.withLock {
            toolCallCount += 1
            guard toolCallCount <= PetalAgent.toolCallLimit else { return Self.limitMessage }
            return work(document)
        }
    }

    func recordTest(of recipe: PetalAgentRecipe, articles: [ParsedArticle]) {
        guard Self.isUsable(articles) else { return }
        let score = articles.reduce(0) { total, article in
            total + 2 + (article.publishedDate == nil ? 0 : 1) + (article.imageURL == nil ? 0 : 1)
                + (article.summary == nil ? 0 : 1)
        }
        lock.withLock {
            if score > (bestTest?.score ?? 0) {
                bestTest = (recipe, score)
            }
        }
    }

    static func isUsable(_ articles: [ParsedArticle]) -> Bool {
        articles.count >= 2 && articles.allSatisfy { !$0.title.isEmpty && !$0.url.isEmpty }
    }
}
