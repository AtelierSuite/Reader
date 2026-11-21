import Foundation

public extension BlueskyProvider {

    nonisolated static let authorFeedLimit = 50

    /// Fetches the author's recent posts via `app.bsky.feed.getAuthorFeed`,
    /// skipping replies (via filter) and reposts (skipped in code).
    func fetchAuthorFeed(handle: String) async -> BlueskyFeedFetchResult {
        let empty = BlueskyFeedFetchResult(posts: [], displayName: nil, profileImageURL: nil)
        guard let did = await Self.resolveDID(forHandle: handle) ?? handle.asDIDIfValid else {
            return empty
        }
        let posts = await Self.fetchAuthorFeedPosts(actor: did)
        if let firstAuthor = posts.first {
            return BlueskyFeedFetchResult(
                posts: posts,
                displayName: firstAuthor.author.isEmpty ? nil : firstAuthor.author,
                profileImageURL: nil
            )
        }
        // Empty feed: fall back to getProfile so the feed row still gets a name/avatar.
        let profile = await Self.fetchActorProfile(actor: did)
        return BlueskyFeedFetchResult(
            posts: [],
            displayName: profile?.displayName,
            profileImageURL: profile?.profileImageURL
        )
    }

    // MARK: - getAuthorFeed

    nonisolated static func fetchAuthorFeedPosts(actor: String) async -> [ParsedBlueskyPost] {
        guard var components = URLComponents(
            string: "https://\(publicAPIHost)/xrpc/app.bsky.feed.getAuthorFeed"
        ) else { return [] }
        components.queryItems = [
            URLQueryItem(name: "actor", value: actor),
            URLQueryItem(name: "limit", value: String(authorFeedLimit)),
            URLQueryItem(name: "filter", value: "posts_no_replies")
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let feed = root["feed"] as? [[String: Any]] else { return [] }
            return feed.compactMap { parseFeedViewPost($0) }
        } catch {
            log("BlueskyFeed", "getAuthorFeed failed - \(error.localizedDescription)")
            return []
        }
    }
}
