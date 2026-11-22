import SwiftUI
import Hanami

extension AddFeedView {

    func addFeed(_ discovered: DiscoveredFeed) {
        guard !XProvider.isFeedURL(discovered.url) || XProvider.isEnabled else {
            return
        }
        guard !InstagramProvider.isFeedURL(discovered.url) || InstagramProvider.isEnabled else {
            return
        }
        if FeedProviderRegistry.adultSite(forFeedURL: discovered.url) != nil {
            Task { await addAdultContentFeed(discovered) }
            return
        }
        if XProvider.isFeedURL(discovered.url) && !feedManager.hasXFeeds {
            pendingXFeed = discovered
            Task {
                let hasSession = XProvider.hasSession()
                if hasSession {
                    await addFeedDirectly(discovered)
                } else {
                    showXLogin = true
                }
            }
            return
        }
        if InstagramProvider.isFeedURL(discovered.url)
            && !feedManager.hasInstagramFeeds {
            pendingInstagramFeed = discovered
            Task {
                let hasSession = InstagramProvider.hasSession()
                if hasSession {
                    await addFeedDirectly(discovered)
                } else {
                    showInstagramLogin = true
                }
            }
            return
        }
        Task { await addFeedDirectly(discovered) }
    }

    func addFeedDirectly(_ discovered: DiscoveredFeed) async {
        guard !addingURLs.contains(discovered.url),
              !addedURLs.contains(discovered.url) else { return }
        addingURLs.insert(discovered.url)
        defer { addingURLs.remove(discovered.url) }
        do {
            _ = try await feedManager.addFeedFetchingMetadata(
                url: discovered.url,
                title: discovered.title,
                siteURL: discovered.siteURL
            )
            addedURLs.insert(discovered.url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addAdultContentFeed(_ discovered: DiscoveredFeed) async {
        guard !addingURLs.contains(discovered.url),
              !addedURLs.contains(discovered.url) else { return }
        errorMessage = nil
        addingURLs.insert(discovered.url)
        let result = await AdultContentGate.authorizeInForeground(feedURL: discovered.url)
        addingURLs.remove(discovered.url)
        switch result {
        case .success: await addFeedDirectly(discovered)
        case .failure(let error): errorMessage = error.localizedMessage
        }
    }

    func addFeedAfterXLogin(_ discovered: DiscoveredFeed) {
        Task {
            let hasSession = XProvider.hasSession()
            if hasSession {
                await addFeedDirectly(discovered)
            }
            pendingXFeed = nil
        }
    }

    func addFeedAfterInstagramLogin(_ discovered: DiscoveredFeed) {
        Task {
            let hasSession = InstagramProvider.hasSession()
            if hasSession {
                await addFeedDirectly(discovered)
            }
            pendingInstagramFeed = nil
        }
    }
}
