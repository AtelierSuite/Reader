import SwiftUI
import Hanami

struct BrowserSearchDiscoveredSection: View {

    @Environment(FeedManager.self) private var feedManager
    let session: FeedDiscoverySession
    let showsGenerateWebFeed: Bool
    let onAdd: (DiscoveredFeed) -> Void
    let onGenerateWebFeed: () -> Void

    private let gridColumns = Array(
        repeating: GridItem(.flexible(), spacing: 16),
        count: BrowserSearchFeedsSection.limit
    )

    private var subscribedURLs: Set<String> {
        Set(feedManager.feeds.map(\.url))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(String(localized: "AddFeed.Section.Discovered", table: "Feeds"))
                    .font(.body.weight(.bold))
                if session.isSearching {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)

            if !session.isSearching {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
                    ForEach(session.discoveredFeeds) { feed in
                        BrowserDiscoveredFeedCell(
                            feed: feed,
                            isAdded: session.addedURLs.contains(feed.url)
                                || subscribedURLs.contains(feed.url),
                            isAdding: session.addingURLs.contains(feed.url),
                            onAdd: { onAdd(feed) }
                        )
                    }
                    if showsGenerateWebFeed {
                        BrowserGenerateWebFeedCell(action: onGenerateWebFeed)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .animation(.smooth.speed(2.0), value: session.isSearching)
    }
}
