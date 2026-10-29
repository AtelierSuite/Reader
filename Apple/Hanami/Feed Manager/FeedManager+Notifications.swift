import Foundation

public extension FeedManager {

    var notifyingFeeds: [Feed] {
        feeds.filter(\.notifiesNewContent)
    }

    func setNotifiesNewContent(_ notifiesNewContent: Bool, for feed: Feed) {
        if notifiesNewContent {
            NewContentNotifications.startTrackingIfNeeded(database: database)
        }
        try? database.updateFeedNotifiesNewContent(id: feed.id, notifiesNewContent: notifiesNewContent)
        if let index = feeds.firstIndex(where: { $0.id == feed.id }) {
            feeds[index].notifiesNewContent = notifiesNewContent
        }
        captureUserFeedEdit(feedID: feed.id)
        NewContentNotifications.postDidChange()
        if !notifiesNewContent {
            Task { await NewContentNotifier.shared.removeDeliveredNotifications(forFeedID: feed.id) }
        }
    }

    nonisolated func postNotificationsForNewContent() async {
        await NewContentNotifier.shared.postNotificationsForNewContent()
    }
}
