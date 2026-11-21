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
    }

    static let toolCallLimit = 24

    public static var isAvailable: Bool {
        guard #available(iOS 27.0, macOS 27.0, *) else { return false }
        return PrivateCloudComputeLanguageModel().isAvailable
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
        let response = try await session.respond(
            to: "Build a feed recipe for \(siteURL).",
            generating: PetalAgentRecipe.self
        )
        let candidates = [response.content, workspace.bestTestedRecipe].compactMap { $0 }
        for candidate in candidates {
            let recipe = candidate.recipe(name: workspace.pageTitle, siteURL: siteURL)
            if PetalAgentWorkspace.isUsable(PetalEngine.parse(html: html, recipe: recipe)) {
                return recipe
            }
        }
        throw Failure.noWorkingRecipe
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
        4. Call testRecipe. Fix any field that comes back empty or wrong and test again.
        5. When the test looks right, answer with the final recipe.

        Rules:
        - Prefer short, stable selectors built from tag names and meaningful class names or \
        attributes. Avoid generated class names (random letters or hashes), nth-child and long \
        descendant chains.
        - titleSelector must match the entry's headline text. linkSelector must match the <a> \
        that leads to the entry; leave it empty when the item element itself is the link.
        - dateSelector should match a <time> element or the element holding the date; set \
        dateAttribute (for example "datetime") when the date is in an attribute.
        - Leave a field empty when the page has nothing suitable. Never invent selectors you \
        have not seen in tool output.
        - You have a limited number of tool calls, so do not repeat a call with the same arguments.
        """
}
