import Foundation

extension BlueskyProvider {

    nonisolated static let authenticationPlaceholderPhrases = [
        "requires authentication", "log in", "logged in", "sign in", "signed in"
    ]

    nonisolated static func resolvedTarget(_ target: BlueskyFeedTarget) async -> BlueskyFeedTarget? {
        if target.actor.asDIDIfValid != nil { return target }
        guard let did = await resolveDID(forHandle: target.actor) else { return nil }
        return target.withActor(did)
    }

    nonisolated static func fetchTargetContent(
        _ target: BlueskyFeedTarget, pageCount: Int
    ) async throws -> ProviderFeedContent {
        let metadata = try await fetchTargetMetadata(target)
        let posts: [ParsedBlueskyPost]
        switch target.kind {
        case .feed:
            posts = try await fetchPostPages(
                "app.bsky.feed.getFeed",
                query: [URLQueryItem(name: "feed", value: target.atURI)],
                pageCount: pageCount
            )
            if isAuthenticationPlaceholder(posts) { throw BlueskyAPIError.authenticationRequired }
        case .list, .starterPack:
            guard let listURI = metadata.listURI else {
                throw BlueskyAPIError.requestFailed(status: 200, message: "Missing list")
            }
            posts = try await fetchPostPages(
                "app.bsky.feed.getListFeed",
                query: [URLQueryItem(name: "list", value: listURI)],
                pageCount: pageCount
            )
        }
        return ProviderFeedContent(
            items: articleItems(from: posts), title: metadata.title, profileImageURL: metadata.avatarURL
        )
    }

    nonisolated static func fetchTargetMetadata(_ target: BlueskyFeedTarget) async throws -> BlueskyTargetMetadata {
        switch target.kind {
        case .feed:
            let root = try await xrpc(
                "app.bsky.feed.getFeedGenerator", query: [URLQueryItem(name: "feed", value: target.atURI)]
            )
            let view = root["view"] as? [String: Any]
            return BlueskyTargetMetadata(
                title: nonEmpty(view?["displayName"]), avatarURL: nonEmpty(view?["avatar"]), listURI: nil
            )
        case .list:
            let root = try await xrpc(
                "app.bsky.graph.getList",
                query: [URLQueryItem(name: "list", value: target.atURI), URLQueryItem(name: "limit", value: "1")]
            )
            let list = root["list"] as? [String: Any]
            return BlueskyTargetMetadata(
                title: nonEmpty(list?["name"]), avatarURL: nonEmpty(list?["avatar"]), listURI: nonEmpty(list?["uri"])
            )
        case .starterPack:
            let root = try await xrpc(
                "app.bsky.graph.getStarterPack", query: [URLQueryItem(name: "starterPack", value: target.atURI)]
            )
            let starterPack = root["starterPack"] as? [String: Any]
            let record = starterPack?["record"] as? [String: Any]
            let list = starterPack?["list"] as? [String: Any]
            let creator = starterPack?["creator"] as? [String: Any]
            return BlueskyTargetMetadata(
                title: nonEmpty(record?["name"]) ?? nonEmpty(list?["name"]),
                avatarURL: nonEmpty(list?["avatar"]) ?? nonEmpty(creator?["avatar"]),
                listURI: nonEmpty(list?["uri"]) ?? nonEmpty(record?["list"])
            )
        }
    }

    nonisolated static func isAuthenticationPlaceholder(_ posts: [ParsedBlueskyPost]) -> Bool {
        guard !posts.isEmpty, posts.count <= 2 else { return false }
        return posts.allSatisfy { post in
            let text = post.text.lowercased()
            return authenticationPlaceholderPhrases.contains { text.contains($0) }
        }
    }

    private nonisolated static func nonEmpty(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        return string
    }
}
