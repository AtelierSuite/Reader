import Foundation
@preconcurrency import UserNotifications

/// Becomes the notification center delegate at launch, because a tap that
/// launches the app arrives before any view can handle it. The tapped
/// content waits here until a handler is installed.
public final class NewContentNotificationResponder: NSObject, UNUserNotificationCenterDelegate {

    public static let shared = NewContentNotificationResponder()

    private var pendingArticleID: Int64?
    private var openArticle: ((Int64) -> Void)?

    public func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    public func setOpenArticleHandler(_ handler: @escaping (Int64) -> Void) {
        openArticle = handler
        if let pendingArticleID {
            self.pendingArticleID = nil
            handler(pendingArticleID)
        }
    }

    private func open(articleID: Int64) {
        if let openArticle {
            openArticle(articleID)
        } else {
            pendingArticleID = articleID
        }
    }

    /// The content is already on screen when the app is in front, so these
    /// go straight to Notification Center without a banner.
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        NewContentNotifier.articleID(of: notification) == nil ? [.banner, .list, .sound] : [.list]
    }

    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let articleID = NewContentNotifier.articleID(of: response) else { return }
        await MainActor.run {
            open(articleID: articleID)
        }
    }
}
