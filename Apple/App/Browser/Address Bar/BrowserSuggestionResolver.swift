import Foundation
import Hanami

/// Turns what the user typed into the omnibox into the mix of feeds, content
/// and actions Safari shows under its address field.
@MainActor
struct BrowserSuggestionResolver {

    private static let feedLimit = BrowserOmniboxFeedGrid.columnCount * 2
    private static let listLimit = 3

    let feedManager: FeedManager

    /// `discoveredFeedURLs` keeps feeds followed from Discovered Feeds under
    /// Feeds even when they live on another host than the one typed.
    func suggestions(
        for query: String,
        contentMatches: [Article],
        discoveredFeedURLs: Set<String> = []
    ) -> [BrowserSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return emptyQuerySuggestions() }

        var results: [BrowserSuggestion] = []
        if BrowserAddressInput.siteHost(from: trimmed) == nil {
            results.append(BrowserSuggestion(
                id: "search:\(trimmed)",
                kind: .searchContent(trimmed),
                section: .actions
            ))
        }
        results += matchingFeeds(trimmed, discoveredFeedURLs: discoveredFeedURLs).map {
            BrowserSuggestion(id: "feed:\($0.id)", kind: .feed($0), section: .feeds)
        }
        results += matchingLists(trimmed).map {
            BrowserSuggestion(id: "list:\($0.id)", kind: .list($0), section: .lists)
        }
        results += contentMatches.map {
            BrowserSuggestion(id: "article:\($0.id)", kind: .article($0), section: .content)
        }
        return results
    }

    private func emptyQuerySuggestions() -> [BrowserSuggestion] {
        [BrowserLocation.startPage, .allContent, .feeds].map {
            BrowserSuggestion(id: "place:\($0.persistenceToken)", kind: .place($0), section: .places)
        }
    }

    private func matchingFeeds(_ query: String, discoveredFeedURLs: Set<String>) -> [Feed] {
        let needle = query.lowercased()
        return feedManager.feeds
            .filter {
                discoveredFeedURLs.contains($0.url)
                    || $0.title.lowercased().contains(needle)
                    || $0.domain.lowercased().contains(needle)
            }
            .prefix(BrowserSuggestionResolver.feedLimit)
            .map { $0 }
    }

    private func matchingLists(_ query: String) -> [FeedList] {
        let needle = query.lowercased()
        return feedManager.lists
            .filter { $0.name.lowercased().contains(needle) }
            .prefix(BrowserSuggestionResolver.listLimit)
            .map { $0 }
    }
}
