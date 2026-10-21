import Foundation
@preconcurrency import SQLite

/// Custom feed icons live in the favicon cache rather than the database, so
/// backups carry them in their own table.
nonisolated enum CustomIconBackupArchive {

    struct Entry: Sendable {
        let feedID: Int64
        let iconData: Data
    }

    private static let table = Table("custom_icon_backup")
    private static let feedID = Expression<Int64>("feed_id")
    private static let iconData = Expression<Blob>("icon_data")

    static func write(_ entries: [Entry], to connection: Connection) throws {
        try connection.run(table.create(ifNotExists: true) { builder in
            builder.column(feedID, primaryKey: true)
            builder.column(iconData)
        })
        try connection.transaction {
            try connection.run(table.delete())
            for entry in entries {
                try connection.run(table.insert(
                    feedID <- entry.feedID,
                    iconData <- Blob(bytes: Array(entry.iconData))
                ))
            }
        }
    }

    static func read(from connection: Connection) throws -> [Entry] {
        let tableCount = try connection.scalar(
            "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'custom_icon_backup'"
        ) as? Int64 ?? 0
        guard tableCount > 0 else { return [] }
        return try connection.rows(table).map { row in
            Entry(feedID: row[feedID], iconData: Data(row[iconData].bytes))
        }
    }
}
