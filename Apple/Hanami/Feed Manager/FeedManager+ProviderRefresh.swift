import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public nonisolated struct ProviderFeedContent: Sendable {
    public var items: [ArticleInsertItem]
    public var title: String?
    public var profileImageURL: String?

    public init(items: [ArticleInsertItem], title: String? = nil, profileImageURL: String? = nil) {
        self.items = items
        self.title = title
        self.profileImageURL = profileImageURL
    }
}

public extension FeedManager {

    func storeProviderFeedContent(
        _ content: ProviderFeedContent,
        for feed: Feed,
        options: FeedRefreshOptions,
        logTag: String
    ) async throws {
        let feedTitle = content.title ?? feed.title
        let profileImage = await loadProviderProfileImage(
            urlString: content.profileImageURL, feed: feed, contentOnly: options.contentOnly
        )

        let database = database
        let feedID = feed.id
        let items = content.items
        let pipelineTask = Task.detached {
            let insertedIDs = (try? database.insertArticles(feedID: feedID, articles: items)) ?? []
            log(logTag, "inserted id=\(feedID) new=\(insertedIDs.count)/\(items.count)")
            await FeedManager.runPostInsertPipeline(
                insertedIDs: insertedIDs,
                feedTitle: feedTitle,
                skipImagePreload: options.skipImagePreload,
                runNLP: options.runNLP
            )
            try database.updateFeedLastFetched(id: feedID, date: Date())
        }
        try await withTaskCancellationHandler {
            try await pipelineTask.value
        } onCancel: {
            pipelineTask.cancel()
        }

        if !options.contentOnly {
            await applyFetcherMetadataRefresh(
                feed: feed, fetchdTitle: feedTitle, profileImage: profileImage
            )
        }
        if options.reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
    }

    private func loadProviderProfileImage(
        urlString: String?, feed: Feed, contentOnly: Bool
    ) async -> PlatformImage? {
        guard !contentOnly, let urlString, let imageURL = URL(string: urlString) else { return nil }
        if feed.lastFetched != nil, await Iconography.shared.hasProfilePhoto(for: feed) {
            return nil
        }
        guard let (imageData, _) = try? await Iconography.urlSession.data(from: imageURL) else {
            return nil
        }
        return PlatformImage(data: imageData)
    }
}
