import Foundation
import FoundationModels

/// Works out a Web Feed recipe by letting a Private Cloud Compute model explore the page with tools.
public nonisolated enum PetalAgent {

    public enum Step: Sendable, Equatable {
        case readingPage
        case tryingSelectors
        case testingFeed
    }

    public enum Failure: Error {
        case unavailable
        case noWorkingRecipe
        case toolCallLimitExceeded
        case timedOut
    }

    static let toolCallLimit = 16
    static let toolCallGrace = 3
    static let timeLimit: Duration = .seconds(120)

    public static var isAvailable: Bool {
        guard #available(iOS 27.0, macOS 27.0, *) else { return false }
        return PrivateCloudComputeLanguageModel().isAvailable
    }

    /// The HTML the server sends holds no list to work from, so the page has to be rendered first.
    public static func pageNeedsRendering(html: String, siteURL: String) -> Bool {
        PetalAgentWorkspace.looksUnrendered(html: html, siteURL: siteURL)
    }

    public static func buildRecipe(
        html: String,
        siteURL: String,
        onStep: @escaping @Sendable (Step) -> Void = { _ in }
    ) async throws -> PetalRecipe {
        guard #available(iOS 27.0, macOS 27.0, *), isAvailable else { throw Failure.unavailable }
        guard let workspace = PetalAgentWorkspace(html: html, siteURL: siteURL, onStep: onStep) else {
            throw Failure.noWorkingRecipe
        }
        let session = LanguageModelSession(
            model: PrivateCloudComputeLanguageModel(),
            tools: [
                PetalOutlineTool(workspace: workspace),
                PetalSelectTool(workspace: workspace),
                PetalInspectTool(workspace: workspace),
                PetalTestRecipeTool(workspace: workspace)
            ],
            instructions: instructions
        )
        log("WebFeedAgent", "start \(siteURL) html=\(html.count)")
        var answer: PetalAgentRecipe?
        do {
            answer = try await withTimeLimit {
                try await session.respond(
                    to: "Build a feed recipe for \(siteURL).",
                    generating: PetalAgentRecipe.self
                ).content
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            log("WebFeedAgent", "model failed: \(error) quota=\(PrivateCloudComputeLanguageModel().quotaUsage)")
        }
        for candidate in [answer, workspace.bestTestedRecipe].compactMap({ $0 }) {
            let recipe = candidate.recipe(name: workspace.pageTitle, siteURL: siteURL)
            let diagnosis = PetalEngine.diagnose(html: html, recipe: recipe)
            if PetalAgentWorkspace.score(diagnosis) > 0 {
                log("WebFeedAgent", "recipe item=\(recipe.itemSelector) title=\(recipe.titleSelector ?? "-")")
                return withoutDeadSelectors(recipe, diagnosis: diagnosis)
            }
        }
        log("WebFeedAgent", "no working recipe")
        throw Failure.noWorkingRecipe
    }

    private static func withoutDeadSelectors(_ recipe: PetalRecipe, diagnosis: PetalRecipeDiagnosis) -> PetalRecipe {
        var cleaned = recipe
        for field in diagnosis.invalidSelectors + diagnosis.unmatchedSelectors {
            switch field {
            case "summary": cleaned.summarySelector = nil
            case "image": cleaned.imageSelector = nil
            case "author": cleaned.authorSelector = nil
            case "date":
                cleaned.dateSelector = nil
                cleaned.dateAttribute = nil
            default: break
            }
        }
        return cleaned
    }

    private static func withTimeLimit<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try await withThrowingTaskGroup(of: Value.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: timeLimit)
                throw Failure.timedOut
            }
            defer { group.cancelAll() }
            guard let value = try await group.next() else { throw Failure.timedOut }
            return value
        }
    }

    private static let instructions = """
        You turn a web page into a feed by choosing CSS selectors. The page is already loaded; \
        you can only see it through your tools.

        Work in this order:
        1. Call outline to see the page structure and find the repeating block that holds the \
        list of posts, stories, products or other entries. Ignore navigation, sidebars, footers \
        and "related" or "trending" widgets unless the page has nothing else.
        2. Call select with a candidate item selector. It should match every entry and nothing \
        else, usually between 3 and 100 elements.
        3. Call inspect on one matched item to see its inner markup, then choose selectors for \
        the fields. Field selectors are relative to the item, not the page.
        4. Call testRecipe. If a field comes back empty or wrong, change its selector and test \
        again. Try to fix a field at most twice; a missing summary, image, date or author is fine.
        5. As soon as titles and links are right, answer with the final recipe.

        Rules:
        - Prefer short, stable selectors built from tag names and meaningful class names or \
        attributes. Avoid generated class names (random letters or hashes), nth-child and long \
        descendant chains.
        - titleSelector must match the entry's headline text. linkSelector must match the <a> \
        that leads to the entry; leave it empty when the item element itself is the link.
        - dateSelector should match a <time> element or the element holding the date; set \
        dateAttribute (for example "datetime") when the date is in an attribute. The outline \
        marks these as time[datetime].
        - imageSelector should match the entry's own picture, not an author avatar or icon. \
        Lazy-loaded images are read from data-src or srcset automatically.
        - Class names with characters other than letters, digits, - and _ are left out of the \
        outline; do not use them.
        - Every field selector is evaluated inside the item element. It cannot reach a parent \
        or a sibling of the item, so leave a field empty when its data sits outside the item.
        - Leave a field empty when the page has nothing suitable. Never invent selectors you \
        have not seen in tool output.
        - You have a limited number of tool calls, so do not repeat a call with the same arguments.
        """
}
