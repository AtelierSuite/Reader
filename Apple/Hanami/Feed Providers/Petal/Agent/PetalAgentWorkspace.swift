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

    /// Runs `work` against the page. Past the limit the model is told to answer, and stopped if it keeps calling.
    func perform(_ step: PetalAgent.Step, _ work: (Document) -> String) throws -> String {
        onStep(step)
        let (callNumber, output) = lock.withLock {
            toolCallCount += 1
            let output = toolCallCount <= PetalAgent.toolCallLimit ? work(document) : Self.limitMessage
            return (toolCallCount, output)
        }
        log("WebFeedAgent", "tool call \(callNumber) \(step): \(output.prefix(300))")
        guard callNumber <= PetalAgent.toolCallLimit + PetalAgent.toolCallGrace else {
            throw PetalAgent.Failure.toolCallLimitExceeded
        }
        return output
    }

    func recordTest(of recipe: PetalAgentRecipe, articles: [ParsedArticle]) {
        guard Self.isUsable(articles) else { return }
        let score = Self.score(articles)
        lock.withLock {
            if score > (bestTest?.score ?? 0) {
                bestTest = (recipe, score)
            }
        }
    }

    static func score(_ articles: [ParsedArticle]) -> Int {
        articles.reduce(0) { total, article in
            total + 2 + (article.publishedDate == nil ? 0 : 1) + (article.imageURL == nil ? 0 : 1)
                + (article.summary == nil ? 0 : 1)
        }
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
