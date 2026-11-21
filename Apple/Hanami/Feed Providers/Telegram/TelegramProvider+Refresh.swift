import Foundation

extension TelegramProvider: WebFeedProvider {

    public static func refresh(
        feed: Feed,
        on manager: FeedManager,
        options: FeedRefreshOptions
    ) async throws {
        guard let channel = identifierFromFeedURL(feed.url) else { return }
        let result = try await TelegramProvider().fetchChannel(channel)
        log("Telegram", "fetched channel=\(channel) id=\(feed.id) posts=\(result.posts.count)")
        let author = result.title ?? feed.title
        let items = result.posts.map { articleItem(from: $0, author: author) }
        try await manager.storeProviderFeedContent(
            ProviderFeedContent(items: items, title: result.title, profileImageURL: result.avatarURL),
            for: feed,
            options: options,
            logTag: "Telegram"
        )
    }

    private nonisolated static func articleItem(
        from post: ParsedTelegramPost, author: String
    ) -> ArticleInsertItem {
        let title = [post.mediaLabel, post.headline.map { String($0.prefix(200)) }]
            .compactMap { $0 }
            .joined(separator: " ")
        return ArticleInsertItem(
            title: title.isEmpty ? "Post by \(author)" : title,
            url: post.url,
            data: ArticleInsertData(
                author: author,
                summary: post.text.isEmpty ? nil : post.text,
                imageURL: post.imageURLs.first,
                carouselImageURLs: post.imageURLs.count > 1 ? post.imageURLs : [],
                publishedDate: post.publishedDate
            )
        )
    }
}
