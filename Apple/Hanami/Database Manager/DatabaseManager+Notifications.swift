import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    /// Runs on every launch because `fixup()` only runs when the version changes.
    func migrateNotificationColumns() {
        _ = try? database.run(feeds.addColumn(feedNotifiesNewContent, defaultValue: false))
    }

    func updateFeedNotifiesNewContent(id: Int64, notifiesNewContent: Bool) throws {
        let target = feeds.filter(feedID == id)
        try database.run(target.update(feedNotifiesNewContent <- notifiesNewContent))
    }

    func notifyingFeedIDs() throws -> [Int64] {
        try readDatabase.rows(
            feeds.filter(feedNotifiesNewContent == true).select(feedID)
        ).map { $0[feedID] }
    }

    /// Unread content inserted after `articleID`, newest first.
    func unreadArticles(insertedAfter lastArticleID: Int64, feedIDs: [Int64]) throws -> [Article] {
        guard !feedIDs.isEmpty else { return [] }
        let query = selectingListColumns(articles)
            .filter(articleID > lastArticleID
                    && feedIDs.contains(articleFeedID)
                    && articleIsRead == false)
            .order(articleID.desc)
        return try readDatabase.rows(query).map(rowToListArticle)
    }

    func unreadArticleIDs(among articleIDs: [Int64]) throws -> Set<Int64> {
        guard !articleIDs.isEmpty else { return [] }
        let query = articles
            .filter(articleIDs.contains(articleID) && articleIsRead == false)
            .select(articleID)
        return Set(try readDatabase.rows(query).map { $0[articleID] })
    }
}
