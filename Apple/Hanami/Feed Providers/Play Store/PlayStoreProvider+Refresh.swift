import Foundation

extension PlayStoreProvider: WebFeedProvider {

    public static func refresh(
        feed: Feed,
        on manager: FeedManager,
        options: FeedRefreshOptions
    ) async throws {
        if let lastFetched = feed.lastFetched, Date().timeIntervalSince(lastFetched) < refreshInterval {
            return
        }
        guard let target = PlayStoreFeedTarget(feedURL: feed.url) else { return }
        let provider = PlayStoreProvider()
        if target.isDeveloper {
            try await refreshDeveloper(target: target, provider: provider, feed: feed, on: manager, options: options)
        } else {
            try await refreshApp(target: target, provider: provider, feed: feed, on: manager, options: options)
        }
    }

    private static func refreshApp(
        target: PlayStoreFeedTarget,
        provider: PlayStoreProvider,
        feed: Feed,
        on manager: FeedManager,
        options: FeedRefreshOptions
    ) async throws {
        let details = try await provider.fetchAppDetails(for: target)
        let items = [appVersionItem(for: details, target: target)]
        log("PlayStore", "fetched id=\(feed.id) kind=app articles=\(items.count)")
        try await manager.storeProviderFeedContent(
            ProviderFeedContent(
                items: items,
                title: details.title,
                profileImageURL: details.iconURL
            ),
            for: feed,
            options: options,
            logTag: "PlayStore"
        )
    }

    private static func refreshDeveloper(
        target: PlayStoreFeedTarget,
        provider: PlayStoreProvider,
        feed: Feed,
        on manager: FeedManager,
        options: FeedRefreshOptions
    ) async throws {
        let page = try await provider.fetchDeveloperPage(for: target)
        let items = page.apps.map { developerAppItem(for: $0, developerName: page.developerName, country: target.country) }
        log("PlayStore", "fetched id=\(feed.id) kind=developer articles=\(items.count)")
        try await manager.storeProviderFeedContent(
            ProviderFeedContent(
                items: items,
                title: page.developerName,
                profileImageURL: page.iconURL
            ),
            for: feed,
            options: options,
            logTag: "PlayStore"
        )
    }

    private nonisolated static func appVersionItem(
        for details: PlayStoreAppDetails,
        target: PlayStoreFeedTarget
    ) -> ArticleInsertItem {
        let versionToken: String
        let title: String
        if let version = details.version?.trimmingCharacters(in: .whitespacesAndNewlines), !version.isEmpty {
            versionToken = version
            title = "\(details.title) \(version)"
        } else if let updatedDate = details.updatedDate {
            versionToken = String(Int(updatedDate.timeIntervalSince1970))
            title = "\(details.title) (\(formattedDate(updatedDate)))"
        } else {
            versionToken = "latest"
            title = details.title
        }

        var components = URLComponents(string: target.siteURL)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "version", value: versionToken))
        components?.queryItems = queryItems

        let plainNotes = plainText(fromHTML: details.releaseNotesHTML) ?? details.summary
        let trimmedNotes = plainNotes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return ArticleInsertItem(
            title: title,
            url: components?.string ?? target.siteURL,
            data: ArticleInsertData(
                author: details.developerName,
                summary: trimmedNotes.isEmpty ? nil : trimmedNotes,
                content: trimmedNotes.isEmpty ? nil : RSSParser.paragraphHTML(fromPlainText: trimmedNotes),
                imageURL: details.iconURL,
                publishedDate: details.updatedDate
            )
        )
    }

    private nonisolated static func developerAppItem(
        for app: PlayStoreDeveloperApp,
        developerName: String?,
        country: String
    ) -> ArticleInsertItem {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "play.google.com"
        components.path = "/store/apps/details"
        components.queryItems = [
            URLQueryItem(name: "id", value: app.packageIdentifier),
            URLQueryItem(name: "gl", value: country.uppercased())
        ]

        let plainDescription = plainText(fromHTML: app.descriptionHTML) ?? ""
        return ArticleInsertItem(
            title: app.title,
            url: components.string ?? "https://play.google.com/store/apps/details?id=\(app.packageIdentifier)",
            data: ArticleInsertData(
                author: app.developerName ?? developerName,
                summary: plainDescription.isEmpty ? nil : plainDescription,
                content: plainDescription.isEmpty ? nil : RSSParser.paragraphHTML(fromPlainText: plainDescription),
                imageURL: app.iconURL,
                publishedDate: nil
            )
        )
    }

    private nonisolated static func plainText(fromHTML html: String?) -> String? {
        guard let html, !html.isEmpty else { return nil }
        let withNewlines = html
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        let stripped = RSSParser.stripHTMLTags(withNewlines)
        let decoded = RSSParser.decodeHTMLEntities(stripped)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return decoded.isEmpty ? nil : decoded
    }

    private nonisolated static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
