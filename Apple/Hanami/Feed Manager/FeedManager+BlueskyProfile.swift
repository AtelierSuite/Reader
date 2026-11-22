import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public extension FeedManager {

    // MARK: - Bluesky Profile Feeds

    func refreshBlueskyFeed(
        _ feed: Feed,
        reloadData: Bool = true,
        skipImagePreload: Bool = false,
        runNLP: Bool = true,
        contentOnly: Bool = false
    ) async throws {
        log("BlueskyProfile", "refresh begin id=\(feed.id) title=\(feed.title) contentOnly=\(contentOnly)")
        if let lastFetched = feed.lastFetched,
           let interval = RefreshTimeoutDomains.refreshTimeout(for: feed.domain),
           Date().timeIntervalSince(lastFetched) < interval {
            let remaining = interval - Date().timeIntervalSince(lastFetched)
            log("BlueskyProfile", "Skipping refresh for @\(feed.title) - \(Int(remaining))s until next allowed fetch")
            return
        }

        guard let handle = BlueskyProvider.identifierFromFeedURL(feed.url) else {
            log("BlueskyProfile", "Could not derive handle id=\(feed.id) url=\(feed.url)")
            return
        }
        log("BlueskyProfile", "fetching @\(handle) id=\(feed.id)")

        let fetcher = BlueskyProvider()
        let result = await fetcher.fetchAuthorFeed(
            handle: handle,
            pageCount: feed.lastFetched == nil ? BlueskyProvider.firstFetchPageCount : 1
        )
        log("BlueskyProfile", "fetched @\(handle) posts=\(result.posts.count) displayName=\(result.displayName ?? "nil")")

        let postTuples = BlueskyProvider.articleItems(from: result.posts)
        let feedTitle = result.displayName ?? feed.title
        let profileImage = await loadBlueskyProfileImage(
            result: result, feed: feed, contentOnly: contentOnly
        )

        let database = database
        let feedID = feed.id
        try await Task.detached {
            let insertedIDs = (try? database.insertArticles(
                feedID: feedID, articles: postTuples
            )) ?? []
            log("BlueskyProfile", "inserted id=\(feedID) new=\(insertedIDs.count)/\(postTuples.count)")
            await FeedManager.runPostInsertPipeline(
                insertedIDs: insertedIDs,
                feedTitle: feedTitle,
                skipImagePreload: skipImagePreload,
                runNLP: runNLP
            )
            try database.updateFeedLastFetched(id: feedID, date: Date())
        }.value

        if !contentOnly {
            await applyFetcherMetadataRefresh(
                feed: feed, fetchdTitle: feedTitle, profileImage: profileImage
            )
        }

        if reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
        log("BlueskyProfile", "refresh end id=\(feed.id)")
    }

    private func loadBlueskyProfileImage(
        result: BlueskyFeedFetchResult, feed: Feed, contentOnly: Bool
    ) async -> PlatformImage? {
        guard !contentOnly, feed.lastFetched == nil,
              let imageURLString = result.profileImageURL,
              let imageURL = URL(string: imageURLString),
              let (imageData, _) = try? await Iconography.urlSession.data(from: imageURL) else {
            return nil
        }
        return PlatformImage(data: imageData)
    }

    var hasBlueskyFeeds: Bool {
        feeds.contains { BlueskyProvider.isFeedURL($0.url) }
    }
}
