import Foundation

public extension FeedManager {

    /// Widgets read the database directly, so they must re-apply the rules the app filters with.
    /// Over-fetches and grows the window until enough articles survive filtering.
    nonisolated static func visibleArticles(
        limit: Int,
        fetch: (Int) throws -> [Article],
        filter: ([Article]) -> [Article]
    ) rethrows -> [Article] {
        var fetchLimit = max(limit * 4, 100)
        let maxIterations = 5
        for _ in 0..<maxIterations {
            let raw = try fetch(fetchLimit)
            let visible = filter(raw)
            if visible.count >= limit || raw.count < fetchLimit {
                return Array(visible.prefix(limit))
            }
            fetchLimit *= 2
        }
        return Array(filter(try fetch(fetchLimit)).prefix(limit))
    }
}
