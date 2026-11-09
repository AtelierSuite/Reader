import Foundation

public extension XProvider {

    private static let storedQueryIDsDefaultsKey = "X.QueryIDs"

    private nonisolated struct StoredQueryIDs: Codable {
        let userByScreenName: String
        let userTweets: String
        let tweetDetail: String
        let tweetResultByRestId: String
    }

    @MainActor
    internal static func restoreStoredQueryIDs() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: storedQueryIDsDefaultsKey),
              let stored = try? JSONDecoder().decode(StoredQueryIDs.self, from: data) else {
            return false
        }
        userByScreenNameQueryID = stored.userByScreenName
        userTweetsQueryID = stored.userTweets
        tweetDetailQueryID = stored.tweetDetail
        tweetResultByRestIdQueryID = stored.tweetResultByRestId
        return true
    }

    @MainActor
    internal static func storeQueryIDs() {
        guard let userByScreenName = userByScreenNameQueryID,
              let userTweets = userTweetsQueryID,
              let tweetDetail = tweetDetailQueryID,
              let tweetResultByRestId = tweetResultByRestIdQueryID,
              let data = try? JSONEncoder().encode(StoredQueryIDs(
                  userByScreenName: userByScreenName,
                  userTweets: userTweets,
                  tweetDetail: tweetDetail,
                  tweetResultByRestId: tweetResultByRestId
              )) else { return }
        UserDefaults.standard.set(data, forKey: storedQueryIDsDefaultsKey)
    }

    @MainActor
    internal static func forgetQueryIDs() {
        userByScreenNameQueryID = nil
        userTweetsQueryID = nil
        tweetDetailQueryID = nil
        tweetResultByRestIdQueryID = nil
        queryIDsFetched = false
        queryIDsRestoredFromStorage = false
        UserDefaults.standard.removeObject(forKey: storedQueryIDsDefaultsKey)
    }

    /// Discards the current query IDs and extracts fresh ones from the x.com bundle.
    @MainActor
    static func refetchQueryIDs() async {
        forgetQueryIDs()
        await fetchQueryIDsIfNeeded()
    }

    /// Stored IDs go stale when X ships a new bundle, so a failed profile fetch
    /// refetches them once. Freshly extracted IDs are left alone, since the
    /// failure must have another cause.
    @MainActor
    static func refetchQueryIDsIfRestoredFromStorage() async -> Bool {
        guard queryIDsRestoredFromStorage else { return false }
        log("XProvider:QueryIDs", "Stored query IDs may be stale, refetching")
        await refetchQueryIDs()
        return true
    }
}
