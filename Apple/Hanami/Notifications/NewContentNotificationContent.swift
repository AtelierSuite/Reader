import Foundation
@preconcurrency import UserNotifications

nonisolated enum NewContentNotificationContent {

    private static let maximumBodyLength = 240

    static func make(
        for article: Article,
        in feed: Feed,
        database: DatabaseManager
    ) async -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let title = article.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            content.title = feed.title
        } else {
            content.title = title
            content.subtitle = feed.title
        }
        content.body = body(for: article, title: title)
        content.sound = .default
        content.threadIdentifier = "feed.\(feed.id)"
        content.targetContentIdentifier = NewContentNotifier.requestIdentifier(forArticleID: article.id)
        content.userInfo = [
            NewContentNotifier.articleIDUserInfoKey: article.id,
            NewContentNotifier.feedIDUserInfoKey: feed.id
        ]
        if let thumbnailURL = article.imageURL ?? article.carouselImageURLs.first,
           let attachment = await NewContentNotificationThumbnail.attachment(
            imageURL: thumbnailURL, articleID: article.id, database: database
           ) {
            content.attachments = [attachment]
        }
        return content
    }

    /// Posts without a title put their text in the summary, so the title
    /// is repeated there; skip it when it is.
    private static func body(for article: Article, title: String) -> String {
        guard let summary = article.summary.flatMap(SpotlightIndexer.stripMarkup) else { return "" }
        let trimmedSummary = summary.hasPrefix(title) && !title.isEmpty
            ? String(summary.dropFirst(title.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            : summary
        guard trimmedSummary.count > maximumBodyLength else { return trimmedSummary }
        return String(trimmedSummary.prefix(maximumBodyLength)) + "…"
    }
}
