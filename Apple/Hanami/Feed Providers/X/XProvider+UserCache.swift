import Foundation

extension XProvider {

    /// Re-resolving now and then picks up new display names and avatars, and
    /// handles that were renamed or passed on to someone else.
    private static let cachedUserMaximumAge: TimeInterval = 7 * 24 * 60 * 60

    static func recentlyResolvedUserInfo(handle: String) -> UserInfo? {
        guard let cachedUser = LocalDatabaseManager.shared.cachedXUser(handle: handle),
              Date().timeIntervalSince(cachedUser.resolvedAt) < cachedUserMaximumAge else {
            return nil
        }
        return UserInfo(
            id: cachedUser.userID,
            displayName: cachedUser.displayName,
            profileImageURL: cachedUser.profileImageURL
        )
    }
}
