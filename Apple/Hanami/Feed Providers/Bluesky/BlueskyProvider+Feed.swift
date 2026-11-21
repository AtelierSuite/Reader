import Foundation

public extension BlueskyProvider {

    func fetchAuthorFeed(handle: String, pageCount: Int = 1) async -> BlueskyFeedFetchResult {
        let empty = BlueskyFeedFetchResult(posts: [], displayName: nil, profileImageURL: nil)
        guard let did = await Self.resolveDID(forHandle: handle) ?? handle.asDIDIfValid else {
            return empty
        }
        let posts = await Self.fetchAuthorFeedPosts(actor: did, pageCount: pageCount)
        if let firstAuthor = posts.first {
            return BlueskyFeedFetchResult(
                posts: posts,
                displayName: firstAuthor.author.isEmpty ? nil : firstAuthor.author,
                profileImageURL: nil
            )
        }
        let profile = await Self.fetchActorProfile(actor: did)
        return BlueskyFeedFetchResult(
            posts: [],
            displayName: profile?.displayName,
            profileImageURL: profile?.profileImageURL
        )
    }

    nonisolated static func fetchAuthorFeedPosts(actor: String, pageCount: Int = 1) async -> [ParsedBlueskyPost] {
        do {
            return try await fetchPostPages(
                "app.bsky.feed.getAuthorFeed",
                query: [
                    URLQueryItem(name: "actor", value: actor),
                    URLQueryItem(name: "filter", value: "posts_no_replies")
                ],
                pageCount: pageCount
            )
        } catch {
            log("BlueskyFeed", "getAuthorFeed failed - \(error.localizedDescription)")
            return []
        }
    }
}
