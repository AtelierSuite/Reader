import Foundation

extension Iconography {

    nonisolated func customIconData(feedIDs: [Int64]) -> [CustomIconBackupArchive.Entry] {
        feedIDs.compactMap { feedID in
            let fileURL = cacheDirectory.appendingPathComponent(
                sanitizedFileName(Self.customIconCacheKey(feedID: feedID))
            )
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return CustomIconBackupArchive.Entry(feedID: feedID, iconData: data)
        }
    }

    /// Feed IDs in a restored database belong to the backed-up device, so any
    /// cached icon keyed by an old ID would land on the wrong feed.
    func replaceCache(withRestoredCustomIcons entries: [CustomIconBackupArchive.Entry]) {
        clearCache()
        for entry in entries {
            let fileURL = cacheDirectory.appendingPathComponent(
                sanitizedFileName(Self.customIconCacheKey(feedID: entry.feedID))
            )
            try? entry.iconData.write(to: fileURL)
        }
    }
}
