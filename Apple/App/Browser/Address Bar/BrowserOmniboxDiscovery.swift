import SwiftUI
import Hanami

/// Finds feeds behind a typed site address while the omnibox is open, and
/// follows them from there.
@MainActor
struct BrowserOmniboxDiscovery {

    let omnibox: BrowserOmniboxModel
    let feedManager: FeedManager

    func refresh() async {
        let query = omnibox.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard omnibox.isActive,
              let urlString = BrowserAddressInput.normalizedURLString(from: query) else {
            omnibox.discovery = nil
            return
        }
        guard omnibox.discovery?.urlString != urlString else { return }
        omnibox.discovery = nil
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }
        let session = FeedDiscoverySession(urlString: urlString)
        omnibox.discovery = session
        await session.search(urlString)
    }

    func add(_ feed: DiscoveredFeed) {
        guard let session = omnibox.discovery, session.canAdd(feed) else { return }
        if XProvider.isFeedURL(feed.url) && !feedManager.hasXFeeds && !XProvider.hasSession() {
            omnibox.requestedSheet = .discoveryLogin(.x(feed))
            return
        }
        if InstagramProvider.isFeedURL(feed.url) && !feedManager.hasInstagramFeeds
            && !InstagramProvider.hasSession() {
            omnibox.requestedSheet = .discoveryLogin(.instagram(feed))
            return
        }
        Task { await session.add(feed, to: feedManager) }
    }

    func completeLogin(_ login: BrowserDiscoveryLogin) {
        guard login.hasSession, let session = omnibox.discovery else { return }
        Task { await session.add(login.feed, to: feedManager) }
    }

    func generateWebFeed() {
        guard let session = omnibox.discovery else { return }
        omnibox.requestedSheet = .generateWebFeed(url: session.urlString)
    }
}

enum BrowserDiscoveryLogin {
    case x(DiscoveredFeed)
    case instagram(DiscoveredFeed)

    var feed: DiscoveredFeed {
        switch self {
        case .x(let feed), .instagram(let feed): feed
        }
    }

    var hasSession: Bool {
        switch self {
        case .x: XProvider.hasSession()
        case .instagram: InstagramProvider.hasSession()
        }
    }
}
