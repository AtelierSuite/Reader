import Foundation
import FoundationModels

nonisolated struct PetalOutlineTool: Tool {
    let name = "outline"
    let description = "Shows the page structure as an indented tree of tags, ids and classes. "
        + "×N marks N siblings with the same structure, of which only the first is expanded."
    let workspace: PetalAgentWorkspace

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        try workspace.perform(.readingPage) { PetalAgentWorkspace.outline(of: $0) }
    }
}

nonisolated struct PetalSelectTool: Tool {
    let name = "select"
    let description = "Counts the elements a CSS selector matches on the page and shows the first few."
    let workspace: PetalAgentWorkspace

    @Generable
    struct Arguments {
        @Guide(description: "A CSS selector evaluated against the whole page.")
        var selector: String
    }

    func call(arguments: Arguments) async throws -> String {
        try workspace.perform(.tryingSelectors) {
            PetalAgentWorkspace.describeMatches(for: arguments.selector, in: $0)
        }
    }
}

nonisolated struct PetalInspectTool: Tool {
    let name = "inspect"
    let description = "Returns the HTML of one element matched by a CSS selector, to see what is inside an item."
    let workspace: PetalAgentWorkspace

    @Generable
    struct Arguments {
        @Guide(description: "A CSS selector evaluated against the whole page.")
        var selector: String
        @Guide(description: "Which match to return, starting at 0.")
        var index: Int
    }

    func call(arguments: Arguments) async throws -> String {
        try workspace.perform(.tryingSelectors) {
            PetalAgentWorkspace.markup(for: arguments.selector, index: arguments.index, in: $0)
        }
    }
}
