import Foundation

extension AppStoreProvider: WebFeedProvider {

    public static func refresh(
        feed: Feed,
        on manager: FeedManager,
        options: FeedRefreshOptions
    ) async throws {
        if let lastFetched = feed.lastFetched, Date().timeIntervalSince(lastFetched) < refreshInterval {
            return
        }
        guard let target = AppStoreFeedTarget(feedURL: feed.url) else { return }
        let response = try await AppStoreProvider().lookup(target)
        var items = response.apps.compactMap { articleItem(for: $0, storefront: target.storefront) }
        if target.kind == .app, feed.lastFetched == nil, let app = response.apps.first {
            let knownURLs = Set(items.map(\.url))
            items += await pastVersionItems(for: app, storefront: target.storefront)
                .filter { !knownURLs.contains($0.url) }
        }
        log("AppStore", "fetched id=\(feed.id) kind=\(target.kind.rawValue) articles=\(items.count)")
        let artworkURL = target.kind == .app ? response.apps.first?.artworkUrl512 : nil
        try await manager.storeProviderFeedContent(
            ProviderFeedContent(
                items: items,
                title: displayName(for: target, in: response),
                profileImageURL: artworkURL
            ),
            for: feed,
            options: options,
            logTag: "AppStore"
        )
    }

    private nonisolated static func articleItem(
        for app: AppStoreLookupEntry, storefront: String
    ) -> ArticleInsertItem? {
        guard let trackID = app.trackId, let name = app.trackName, let version = app.version else {
            return nil
        }
        let isFirstRelease = app.releaseDate != nil && app.releaseDate == app.currentVersionReleaseDate
        return versionItem(
            AppStoreVersion(
                version: version,
                releaseNotes: app.releaseNotes,
                releaseDate: app.currentVersionReleaseDate
            ),
            title: isFirstRelease ? "New app: \(name)" : "\(name) \(version)",
            app: app,
            trackID: trackID,
            storefront: storefront
        )
    }

    private nonisolated static func pastVersionItems(
        for app: AppStoreLookupEntry, storefront: String
    ) async -> [ArticleInsertItem] {
        guard let trackID = app.trackId, let name = app.trackName else { return [] }
        let versions = await fetchVersionHistory(
            appID: String(trackID), storefront: storefront, isMacApp: app.isMacApp
        )
        return versions.map { version in
            versionItem(
                version, title: "\(name) \(version.version)", app: app, trackID: trackID, storefront: storefront
            )
        }
    }

    private nonisolated static func versionItem(
        _ version: AppStoreVersion,
        title: String,
        app: AppStoreLookupEntry,
        trackID: Int,
        storefront: String
    ) -> ArticleInsertItem {
        var components = URLComponents(string: "https://apps.apple.com/\(storefront)/app/id\(trackID)")
        components?.queryItems = [URLQueryItem(name: "version", value: version.version)]
            + (app.isMacApp ? [URLQueryItem(name: "platform", value: "mac")] : [])
        let notes = version.releaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ArticleInsertItem(
            title: title,
            url: components?.string ?? "https://apps.apple.com/\(storefront)/app/id\(trackID)",
            data: ArticleInsertData(
                author: app.artistName,
                summary: notes.isEmpty ? nil : notes,
                content: notes.isEmpty ? nil : RSSParser.paragraphHTML(fromPlainText: notes),
                imageURL: app.artworkUrl512,
                publishedDate: version.releaseDate
            )
        )
    }
}
