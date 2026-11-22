import EnhancedNavigation
import SwiftUI
import Hanami

struct BrowserSearchResultsView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Search.DisplayStyle") private var searchDisplayStyle: FeedDisplayStyle = .inbox
    let query: String
    var recordsSearchTerm = true
    @State private var results: [Article] = []
    @State var discovery: FeedDiscoverySession?
    @State var showXLogin = false
    @State var pendingXFeed: DiscoveredFeed?
    @State var showInstagramLogin = false
    @State var pendingInstagramFeed: DiscoveredFeed?
    @State var showPetalBuilder = false
    @AppStorage("Labs.PetalRecipes") var petalRecipesEnabled: Bool = false

    /// Ranked, then cut to one row: the grid is a fixed four columns.
    private var matchingFeeds: [Feed] {
        feedManager.feeds
            .compactMap { feed in feed.searchRank(for: query).map { (feed, $0) } }
            .sorted { $0.1 < $1.1 }
            .prefix(BrowserSearchFeedsSection.limit)
            .map(\.0)
    }

    private var hasImages: Bool {
        results.contains { $0.imageURL != nil }
    }

    private var effectiveStyle: FeedDisplayStyle {
        if !hasImages && searchDisplayStyle.requiresImages { return .inbox }
        if searchDisplayStyle == .podcast { return .inbox }
        return searchDisplayStyle
    }

    var body: some View {
        let feeds = matchingFeeds
        let shownDiscovery = visibleDiscovery
        return DisplayStyleContentView(
            style: effectiveStyle,
            articles: results,
            headerView: headerView(discovery: shownDiscovery, feeds: feeds)
        )
            .overlay {
                if results.isEmpty && feeds.isEmpty && shownDiscovery == nil {
                    ContentUnavailableView {
                        Label(String(localized: "NoResults.Title", table: "Search"),
                              systemImage: "magnifyingglass")
                    } description: {
                        Text(String(localized: "NoResults.Description", table: "Search"))
                    }
                }
            }
            .navigationTitle(query)
            .toolbarTitleDisplayMode(.inline)
            .sakuraBackground()
            .pageMenu {
                BrowserPageDisplayMenu(options: browserDisplayStyleOptions)
            }
            .task(id: query) {
                let found = await Task.detached(priority: .userInitiated) { [query] in
                    (try? DatabaseManager.shared.searchArticles(query: query)) ?? []
                }.value
                guard !Task.isCancelled else { return }
                withAnimation(.smooth.speed(2.0)) {
                    results = found
                }
                if recordsSearchTerm {
                    feedManager.recordSearchTerm(query)
                }
            }
            .task(id: query) {
                await discoverFeeds()
            }
            .sheet(isPresented: $showXLogin) {
                addPendingFeed(pendingXFeed, hasSession: XProvider.hasSession())
                pendingXFeed = nil
            } content: {
                XLoginView()
            }
            .sheet(isPresented: $showInstagramLogin) {
                addPendingFeed(pendingInstagramFeed, hasSession: InstagramProvider.hasSession())
                pendingInstagramFeed = nil
            } content: {
                InstagramLoginView()
            }
            .sheet(isPresented: $showPetalBuilder) {
                PetalBuilderView(mode: .create(initialURL: discovery?.urlString ?? query))
                    .environment(feedManager)
            }
    }

    private func headerView(discovery: FeedDiscoverySession?, feeds: [Feed]) -> AnyView? {
        guard discovery != nil || !feeds.isEmpty else { return nil }
        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                if let discovery {
                    BrowserSearchDiscoveredSection(
                        session: discovery,
                        showsGenerateWebFeed: showsGenerateWebFeed,
                        onAdd: addDiscoveredFeed,
                        onGenerateWebFeed: { showPetalBuilder = true }
                    )
                }
                if !feeds.isEmpty {
                    BrowserSearchFeedsSection(feeds: feeds)
                }
            }
        )
    }

    /// The browser hides the top bar, so the display style goes in the
    /// omnibox's menu instead.
    private var browserDisplayStyleOptions: BrowserDisplayStyleOptions {
        BrowserDisplayStyleOptions(
            displayStyle: $searchDisplayStyle,
            hasImages: hasImages,
            showsTimeline: false
        )
    }
}
