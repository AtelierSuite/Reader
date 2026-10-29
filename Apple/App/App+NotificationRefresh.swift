import Foundation
import Hanami

extension SakuraRSSApp {

    nonisolated private static let lastFullRefreshAtKey = "BackgroundRefresh.LastFullRefreshAt"
    /// The system rarely runs the task exactly on time, so a run that is
    /// slightly early still counts as due.
    nonisolated private static let fullRefreshTolerance: TimeInterval = 10 * 60

    nonisolated static func fullRefreshIntervalMinutes() -> Int? {
        let isEnabled = UserDefaults.standard.object(forKey: "BackgroundRefresh.Enabled") as? Bool ?? true
        guard isEnabled else { return nil }
        let refreshInterval = UserDefaults.standard.integer(forKey: "BackgroundRefresh.Interval")
        return refreshInterval > 0 ? refreshInterval : 240
    }

    /// Runs in between full refreshes only fetch the feeds that notify.
    nonisolated static func isFullRefreshDue() -> Bool {
        guard let minutes = fullRefreshIntervalMinutes() else { return false }
        guard NewContentNotifications.activeCheckIntervalMinutes() != nil else { return true }
        let lastFullRefreshAt = UserDefaults.standard.double(forKey: lastFullRefreshAtKey)
        let elapsed = Date().timeIntervalSince1970 - lastFullRefreshAt
        return elapsed >= TimeInterval(minutes * 60) - fullRefreshTolerance
    }

    nonisolated static func recordFullRefresh() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastFullRefreshAtKey)
    }
}
