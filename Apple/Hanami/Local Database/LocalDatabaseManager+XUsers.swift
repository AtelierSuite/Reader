import Foundation
@preconcurrency import SQLite

public nonisolated struct CachedXUser: Sendable {
    public let userID: String
    public let displayName: String?
    public let profileImageURL: String?
    public let resolvedAt: Date
}

nonisolated extension LocalDatabaseManager {

    private static let xUsers = Table("x_users")
    private static let xUserHandle = SQLite.Expression<String>("handle")
    private static let xUserID = SQLite.Expression<String>("user_id")
    private static let xUserDisplayName = SQLite.Expression<String?>("display_name")
    private static let xUserProfileImageURL = SQLite.Expression<String?>("profile_image_url")
    private static let xUserResolvedAt = SQLite.Expression<Double>("resolved_at")

    static func createXUsersTable(in connection: Connection) throws {
        try connection.run(xUsers.create(ifNotExists: true) { table in
            table.column(xUserHandle, primaryKey: true)
            table.column(xUserID)
            table.column(xUserDisplayName)
            table.column(xUserProfileImageURL)
            table.column(xUserResolvedAt)
        })
    }

    func cachedXUser(handle: String) -> CachedXUser? {
        guard let database,
              let row = try? database.pluck(
                  Self.xUsers.filter(Self.xUserHandle == handle.lowercased())
              ) else { return nil }
        return CachedXUser(
            userID: row[Self.xUserID],
            displayName: row[Self.xUserDisplayName],
            profileImageURL: row[Self.xUserProfileImageURL],
            resolvedAt: Date(timeIntervalSince1970: row[Self.xUserResolvedAt])
        )
    }

    func cacheXUser(handle: String, userID: String, displayName: String?, profileImageURL: String?) {
        _ = try? database?.run(Self.xUsers.insert(
            or: .replace,
            Self.xUserHandle <- handle.lowercased(),
            Self.xUserID <- userID,
            Self.xUserDisplayName <- displayName,
            Self.xUserProfileImageURL <- profileImageURL,
            Self.xUserResolvedAt <- Date().timeIntervalSince1970
        ))
    }

    func forgetXUser(handle: String) {
        _ = try? database?.run(Self.xUsers.filter(Self.xUserHandle == handle.lowercased()).delete())
    }
}
