import SwiftUI
import Hanami

extension BrowserSearchResultsView {

    var showsGenerateWebFeed: Bool {
        guard petalRecipesEnabled, let discovery else { return false }
        return discovery.hasSearched && !discovery.isSearching
    }

    var visibleDiscovery: FeedDiscoverySession? {
        guard let discovery, discovery.hasSearched else { return nil }
        let hasContent = discovery.isSearching || !discovery.discoveredFeeds.isEmpty || showsGenerateWebFeed
        return hasContent ? discovery : nil
    }

    func discoverFeeds() async {
        guard BrowserAddressInput.normalizedURLString(from: query) != nil else {
            discovery = nil
            return
        }
        let session = FeedDiscoverySession(urlString: query)
        discovery = session
        await session.search(query)
    }

    func addDiscoveredFeed(_ feed: DiscoveredFeed) {
        guard let discovery, discovery.canAdd(feed) else { return }
        if XProvider.isFeedURL(feed.url) && !feedManager.hasXFeeds && !XProvider.hasSession() {
            pendingXFeed = feed
            showXLogin = true
            return
        }
        if InstagramProvider.isFeedURL(feed.url) && !feedManager.hasInstagramFeeds
            && !InstagramProvider.hasSession() {
            pendingInstagramFeed = feed
            showInstagramLogin = true
            return
        }
        Task { await discovery.add(feed, to: feedManager) }
    }

    func addPendingFeed(_ feed: DiscoveredFeed?, hasSession: Bool) {
        guard let feed, hasSession, let discovery else { return }
        Task { await discovery.add(feed, to: feedManager) }
    }
}
