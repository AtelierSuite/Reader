import Foundation

extension XProvider {

    func fetchProfileContent(
        handle: String, cookies: XCookies, knownTweetURLs: Set<String>
    ) async -> XProfileFetchResult? {
        let cachedUserInfo = Self.recentlyResolvedUserInfo(handle: handle)
        guard let userInfo = await resolveUserInfo(
            handle: handle, cachedUserInfo: cachedUserInfo, cookies: cookies
        ) else { return nil }

        // swiftlint:disable:next line_length
        log("XProvider", "User info - id: \(userInfo.id), name: \(userInfo.displayName ?? "nil"), cached: \(cachedUserInfo != nil)")

        guard let tweets = await fetchTweets(
            userId: userInfo.id, cookies: cookies, knownTweetURLs: knownTweetURLs
        ) else {
            if cachedUserInfo != nil {
                LocalDatabaseManager.shared.forgetXUser(handle: handle)
            }
            return nil
        }

        log("XProvider", "Fetched \(tweets.count) tweets total")

        Self.persistRotatedCookies()

        return XProfileFetchResult(
            tweets: tweets,
            profileImageURL: userInfo.profileImageURL,
            displayName: userInfo.displayName
        )
    }

    private func resolveUserInfo(
        handle: String, cachedUserInfo: UserInfo?, cookies: XCookies
    ) async -> UserInfo? {
        if let cachedUserInfo { return cachedUserInfo }
        guard let userInfo = await fetchUserInfo(screenName: handle, cookies: cookies) else {
            log("XProvider", "Failed to fetch user info for \(handle)")
            return nil
        }
        LocalDatabaseManager.shared.cacheXUser(
            handle: handle,
            userID: userInfo.id,
            displayName: userInfo.displayName,
            profileImageURL: userInfo.profileImageURL
        )
        return userInfo
    }
}
