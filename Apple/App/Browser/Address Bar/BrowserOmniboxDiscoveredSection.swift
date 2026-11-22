import SwiftUI
import Hanami

struct BrowserOmniboxDiscoveredSection: View {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Labs.PetalRecipes") private var petalRecipesEnabled: Bool = false
    let session: FeedDiscoverySession
    let horizontalPadding: CGFloat
    let onAdd: (DiscoveredFeed) -> Void
    let onGenerateWebFeed: () -> Void

    /// Feeds leave this grid once followed, turning up under Feeds instead.
    private var unfollowedFeeds: [DiscoveredFeed] {
        let followedURLs = Set(feedManager.feeds.map(\.url)).union(session.addedURLs)
        return session.discoveredFeeds.filter { !followedURLs.contains($0.url) }
    }

    private var showsGenerateWebFeed: Bool {
        petalRecipesEnabled && session.hasSearched && !session.isSearching
    }

    private var isVisible: Bool {
        session.hasSearched
            && (session.isSearching || !unfollowedFeeds.isEmpty || showsGenerateWebFeed)
    }

    var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    BrowserOmniboxSectionHeader(
                        title: String(localized: "AddFeed.Section.Discovered", table: "Feeds")
                    )
                    if session.isSearching {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                if !session.isSearching {
                    LazyVGrid(columns: BrowserOmniboxFeedGrid.columns, alignment: .leading, spacing: 16) {
                        ForEach(unfollowedFeeds) { feed in
                            BrowserDiscoveredFeedCell(
                                feed: feed,
                                isAdding: session.addingURLs.contains(feed.url),
                                onAdd: { onAdd(feed) }
                            )
                        }
                        if showsGenerateWebFeed {
                            BrowserGenerateWebFeedCell(action: onGenerateWebFeed)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}
