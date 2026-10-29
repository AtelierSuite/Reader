import Foundation
@preconcurrency import UserNotifications

/// Posts a notification for each new unread piece of content in feeds that
/// have notifications on. An actor so overlapping refreshes can't announce
/// the same content twice.
public actor NewContentNotifier {

    public static let shared = NewContentNotifier()

    static let articleIDUserInfoKey = "articleID"
    static let feedIDUserInfoKey = "feedID"
    private static let maximumPerFeed = 5
    private static let maximumPerCheck = 20
    /// Older content arriving now is usually a backfill, not news.
    private static let maximumContentAge: TimeInterval = 3 * 24 * 60 * 60

    private let database: DatabaseManager

    init(database: DatabaseManager = .shared) {
        self.database = database
    }

    public func postNotificationsForNewContent() async {
        let defaults = UserDefaults.standard
        let latestArticleID = database.latestArticleID()
        guard let lastCheckedArticleID = defaults.object(
            forKey: NewContentNotifications.lastCheckedArticleIDKey
        ) as? Int64 else {
            NewContentNotifications.startTrackingIfNeeded(database: database)
            return
        }
        guard latestArticleID > lastCheckedArticleID else { return }
        defaults.set(latestArticleID, forKey: NewContentNotifications.lastCheckedArticleIDKey)

        let feedIDs = NewContentNotifications.notifyingFeedIDs(database: database)
        guard !feedIDs.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
            log("Notifications", "skipping: not authorized status=\(settings.authorizationStatus.rawValue)")
            return
        }

        let articles = newArticles(after: lastCheckedArticleID, feedIDs: Array(feedIDs))
        guard !articles.isEmpty else { return }
        let feedsByID = Dictionary(
            ((try? database.allFeeds()) ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        log("Notifications", "posting count=\(articles.count)")
        for article in articles {
            guard let feed = feedsByID[article.feedID] else { continue }
            let content = await NewContentNotificationContent.make(
                for: article, in: feed, database: database
            )
            let request = UNNotificationRequest(
                identifier: Self.requestIdentifier(forArticleID: article.id),
                content: content,
                trigger: nil
            )
            do {
                try await center.add(request)
            } catch {
                log("Notifications", "add failed articleID=\(article.id) error=\(error)")
            }
        }
    }

    /// Clears notifications whose content was read or removed since.
    public func removeDeliveredNotificationsForReadContent() async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
        let deliveredArticleIDs = delivered.compactMap(Self.articleID(of:))
        guard !deliveredArticleIDs.isEmpty else { return }
        let unreadArticleIDs = (try? database.unreadArticleIDs(among: deliveredArticleIDs)) ?? []
        let staleIdentifiers = deliveredArticleIDs
            .filter { !unreadArticleIDs.contains($0) }
            .map(Self.requestIdentifier(forArticleID:))
        guard !staleIdentifiers.isEmpty else { return }
        center.removeDeliveredNotifications(withIdentifiers: staleIdentifiers)
    }

    public func removeDeliveredNotifications(forFeedID feedID: Int64) async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
        let identifiers = delivered
            .filter { ($0.request.content.userInfo[Self.feedIDUserInfoKey] as? Int64) == feedID }
            .map(\.request.identifier)
        guard !identifiers.isEmpty else { return }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func newArticles(after lastCheckedArticleID: Int64, feedIDs: [Int64]) -> [Article] {
        let candidates = (try? database.unreadArticles(
            insertedAfter: lastCheckedArticleID, feedIDs: feedIDs
        )) ?? []
        let oldestAllowedDate = Date().addingTimeInterval(-Self.maximumContentAge)
        var countsByFeedID: [Int64: Int] = [:]
        var selected: [Article] = []
        for article in candidates where (article.publishedDate ?? .now) >= oldestAllowedDate {
            let feedCount = countsByFeedID[article.feedID, default: 0]
            guard feedCount < Self.maximumPerFeed else { continue }
            countsByFeedID[article.feedID] = feedCount + 1
            selected.append(article)
            if selected.count >= Self.maximumPerCheck { break }
        }
        return selected.reversed()
    }

    static func requestIdentifier(forArticleID articleID: Int64) -> String {
        "article.\(articleID)"
    }

    public nonisolated static func articleID(of notification: UNNotification) -> Int64? {
        notification.request.content.userInfo[articleIDUserInfoKey] as? Int64
    }

    public nonisolated static func articleID(of response: UNNotificationResponse) -> Int64? {
        articleID(of: response.notification)
    }
}
