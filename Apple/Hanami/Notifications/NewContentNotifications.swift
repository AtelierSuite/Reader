import Foundation
@preconcurrency import UserNotifications

public nonisolated enum NewContentCheckInterval: Int, CaseIterable, Sendable {
    case thirtyMinutes = 30
    case oneHour = 60
}

public nonisolated enum NewContentNotifications {

    public static let enabledKey = "Notifications.Enabled"
    public static let checkIntervalKey = "Notifications.CheckInterval"
    static let lastCheckedArticleIDKey = "Notifications.LastCheckedArticleID"

    /// Posted when anything that affects scheduling changes: the switch,
    /// the interval, or which feeds notify.
    public static let didChangeNotification = Notification.Name("NewContentNotifications.DidChange")

    public static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    public static var checkInterval: NewContentCheckInterval {
        NewContentCheckInterval(rawValue: UserDefaults.standard.integer(forKey: checkIntervalKey)) ?? .oneHour
    }

    /// `nil` when nothing would be notified, so no extra checks are needed.
    public static func activeCheckIntervalMinutes(database: DatabaseManager = .shared) -> Int? {
        guard isEnabled, !((try? database.notifyingFeedIDs()) ?? []).isEmpty else { return nil }
        return checkInterval.rawValue
    }

    public static func notifyingFeedIDs(database: DatabaseManager = .shared) -> Set<Int64> {
        guard isEnabled else { return [] }
        return Set((try? database.notifyingFeedIDs()) ?? [])
    }

    /// Starts from the current newest content so turning notifications on
    /// doesn't announce everything already in the database.
    public static func startTrackingIfNeeded(database: DatabaseManager = .shared) {
        guard UserDefaults.standard.object(forKey: lastCheckedArticleIDKey) == nil else { return }
        UserDefaults.standard.set(database.latestArticleID(), forKey: lastCheckedArticleIDKey)
    }

    public static func postDidChange() {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}

public nonisolated extension NewContentNotifications {

    /// Granting the unread badge alone also reports `.authorized`, so alerts
    /// are checked separately.
    static func canPostAlerts() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return isAllowingAlerts(settings)
    }

    static func isAlertPermissionDenied() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus != .notDetermined && !isAllowingAlerts(settings)
    }

    /// Asks only the first time; afterwards reports whether alerts are allowed.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return isAllowingAlerts(settings) }
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    internal static func isAllowingAlerts(_ settings: UNNotificationSettings) -> Bool {
        let isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        return isAuthorized && settings.alertSetting == .enabled
    }
}
