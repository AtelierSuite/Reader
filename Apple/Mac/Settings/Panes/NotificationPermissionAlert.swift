import AppKit

enum NotificationPermissionAlert {

    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")

    static func present(for window: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = String(localized: "FeedHeader.Notify.Denied.Title", table: "Feeds")
        alert.informativeText = String(localized: "FeedHeader.Notify.Denied.Message", table: "Feeds")
        alert.addButton(withTitle: String(localized: "FeedHeader.Notify.Denied.OpenSettings", table: "Feeds"))
        alert.addButton(withTitle: String(localized: "Shared.Cancel"))
        let openSettings = { (response: NSApplication.ModalResponse) in
            guard response == .alertFirstButtonReturn, let settingsURL else { return }
            NSWorkspace.shared.open(settingsURL)
        }
        if let window {
            alert.beginSheetModal(for: window, completionHandler: openSettings)
        } else {
            openSettings(alert.runModal())
        }
    }
}
