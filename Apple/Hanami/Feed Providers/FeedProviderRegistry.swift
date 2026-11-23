import Foundation

/// Routes stored feed URLs and profile URLs to the correct `FeedProvider`.
public nonisolated enum FeedProviderRegistry {

    public nonisolated(unsafe) static let all: [any FeedProvider.Type] = [
        XProvider.self,
        InstagramProvider.self,
        YouTubePlaylistProvider.self,
        SubstackProvider.self,
        NoteProvider.self,
        BlueskyProvider.self,
        RedditProvider.self,
        HackerNewsProvider.self,
        PixelfedProvider.self,
        TelegramProvider.self,
        AppStoreProvider.self,
        PlayStoreProvider.self,
        PixivProvider.self,
        DMMProvider.self,
        DLsiteProvider.self,
        NetflixProvider.self,
        ArXivProvider.self,
        HatenaBookmarkCommentsProvider.self,
        LemmyCommentsProvider.self,
        ZennCommentsProvider.self,
        QiitaCommentsProvider.self,
        MisskeyCommentsProvider.self,
        MastodonCommentsProvider.self,
        MastodonProvider.self
    ]

    // MARK: - Convenience Fetchers

    public static func metadataFetcher(forSiteURL url: URL) -> (any MetadataProvider.Type)? {
        for provider in all {
            if let metadata = provider as? any MetadataProvider.Type,
               metadata.canFetchMetadata(for: url) {
                return metadata
            }
        }
        return nil
    }

    public static func provider(forFeedURL url: String) -> (any FeedProvider.Type)? {
        all.first { $0.matchesFeedURL(url) }
    }

    /// Best-effort siteURL inferred from a feed URL, for callers (like OPML
    /// import) that have a feed URL but no companion site URL.
    public static func inferredSiteURL(forFeedURL feedURL: String) -> String? {
        for provider in all {
            if let derived = provider.inferredSiteURL(fromFeedURL: feedURL) {
                return derived
            }
        }
        return FeedDiscovery.youTubeSiteURL(fromFeedURL: feedURL)
    }

    public static func commentsProvider(
        for article: Article, in feed: Feed?
    ) -> (any CommentsProvider.Type)? {
        for provider in all {
            if let comments = provider as? any CommentsProvider.Type,
               comments.canProvideComments(for: article, in: feed) {
                return comments
            }
        }
        return nil
    }

    // MARK: - Legacy Auth Cookies

    @MainActor
    public static func migrateAuthenticatedCookies() async {
        let authenticatedProviders: [any Authenticated.Type] = all.compactMap { provider in
            guard provider.enabledFlagKey == nil || provider.isEnabled,
                  let auth = provider as? any Authenticated.Type else {
                return nil
            }
            return auth
        }
        for auth in authenticatedProviders {
            await auth.migrateWebKitCookiesIfNeeded()
        }
    }
}
