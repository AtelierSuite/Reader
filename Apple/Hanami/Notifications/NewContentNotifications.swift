import Foundation

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
