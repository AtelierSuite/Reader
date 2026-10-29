import Foundation

public extension FeedManager {

    var notifyingFeeds: [Feed] {
        feeds.filter(\.notifiesNewContent)
    }

    func setNotifiesNewContent(_ notifiesNewContent: Bool, for feed: Feed) {
        if notifiesNewContent {
            NewContentNotifications.startTrackingIfNeeded(database: database)
            UserDefaults.standard.set(true, forKey: NewContentNotifications.enabledKey)
        }
        try? database.updateFeedNotifiesNewContent(id: feed.id, notifiesNewContent: notifiesNewContent)
        captureUserFeedEdit(feedID: feed.id)
        Task { await loadFromDatabaseInBackground() }
        NewContentNotifications.postDidChange()
        if !notifiesNewContent {
            Task { await NewContentNotifier.shared.removeDeliveredNotifications(forFeedID: feed.id) }
        }
    }

    nonisolated func postNotificationsForNewContent() async {
        await NewContentNotifier.shared.postNotificationsForNewContent()
    }
}
