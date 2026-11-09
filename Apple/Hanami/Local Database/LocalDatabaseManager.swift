import Foundation
@preconcurrency import SQLite

/// Device-local data that is cheap to rebuild, kept out of the main database
/// so it is never synced, exported or included in iCloud backups.
public nonisolated final class LocalDatabaseManager: @unchecked Sendable {

    public static let shared = LocalDatabaseManager()

    static let databaseURL: URL = AppGroup.storageURL.appendingPathComponent("Sakura.local")

    let database: Connection?

    private init() {
        do {
            let connection = try Connection(Self.databaseURL.path)
            try connection.run("PRAGMA journal_mode = WAL")
            try connection.run("PRAGMA synchronous = NORMAL")
            connection.busyTimeout = 5.0
            DatabaseManager.applyDataProtection(atPath: Self.databaseURL.path)
            DatabaseSuspensionGate.shared.register(connection)
            Self.excludeFromDeviceBackup()
            try Self.createTables(in: connection)
            database = connection
        } catch {
            log("LocalDatabase", "open failed error=\(error.localizedDescription)")
            database = nil
        }
    }

    private static func excludeFromDeviceBackup() {
        var url = databaseURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    private static func createTables(in connection: Connection) throws {
        try createXUsersTable(in: connection)
    }
}
