import AppKit
import Hanami

extension SidebarViewController {

    func notifyItem(for feed: Feed) -> NSMenuItem {
        let titleKey = feed.notifiesNewContent ? "FeedHeader.Notify.Off" : "FeedHeader.Notify.On"
        let symbolName = feed.notifiesNewContent ? "bell.fill" : "bell"
        return ActionMenuItem(String(localized: String.LocalizationValue(titleKey), table: "Feeds"),
                              symbolName: symbolName) { [weak self] in
            self?.toggleNotifications(for: feed)
        }
    }

    private func toggleNotifications(for feed: Feed) {
        guard !feed.notifiesNewContent else {
            feedManager.setNotifiesNewContent(false, for: feed)
            return
        }
        Task {
            if await NewContentNotifications.requestAuthorization() {
                feedManager.setNotifiesNewContent(true, for: feed)
            } else {
                NotificationPermissionAlert.present(for: view.window)
            }
        }
    }
}
