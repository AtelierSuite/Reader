import Foundation

public nonisolated enum LemmyCommentsProvider {

    static func postID(from url: URL) -> String? {
        let components = url.pathComponents
        guard components.count == 3, components[1] == "post", components[2].allSatisfy(\.isNumber) else {
            return nil
        }
        return components[2]
    }

    /// Lemmy 1.0 moves its API from v3 to v4, so both are tried.
    static func listURLs(host: String, postID: String, limit: Int) -> [URL] {
        ["v3", "v4"].compactMap { version in
            URL(string: "https://\(host)/api/\(version)/comment/list?post_id=\(postID)"
                + "&sort=Top&type_=All&max_depth=1&limit=\(limit)")
        }
    }

    struct Listing: Decodable {
        let comments: [Entry]
    }

    struct Entry: Decodable {
        let comment: Comment
        let creator: Creator
    }

    struct Comment: Decodable {
        let content: String
        let published: String?
        let apID: String?
        let removed: Bool?
        let deleted: Bool?

        enum CodingKeys: String, CodingKey {
            case content, published, removed, deleted
            case apID = "ap_id"
        }
    }

    struct Creator: Decodable {
        let name: String
        let actorID: String?

        enum CodingKeys: String, CodingKey {
            case name
            case actorID = "actor_id"
        }
    }
}

extension LemmyCommentsProvider: FeedProvider {

    public nonisolated static var providerID: String { "lemmy" }

    public nonisolated static var domains: Set<String> { [] }

    public nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool { false }
}

extension LemmyCommentsProvider: CommentsProvider {

    public nonisolated static func canProvideComments(for article: Article, in feed: Feed?) -> Bool {
        commentsURL(for: article, in: feed) != nil
    }

    public nonisolated static func commentsURL(for article: Article, in feed: Feed?) -> URL? {
        guard let feed, let feedURL = URL(string: feed.fetchURL), LemmyDialect.isFeedURL(feedURL),
              let url = URL(string: article.url), postID(from: url) != nil else { return nil }
        return url
    }

    public static func fetchComments(
        for article: Article, in feed: Feed?, limit: Int
    ) async throws -> [FetchedComment] {
        guard limit > 0, let postURL = commentsURL(for: article, in: feed), let host = postURL.host,
              let postID = postID(from: postURL) else { return [] }
        for listURL in listURLs(host: host, postID: postID, limit: limit) {
            guard let listing = try await JSONCommentsFetching.decode(
                Listing.self, from: .sakura(url: listURL), source: "Lemmy"
            ) else { continue }
            return listing.comments
                .filter { $0.comment.removed != true && $0.comment.deleted != true }
                .prefix(limit)
                .map { entry in
                    FetchedComment(
                        author: entry.creator.actorID.map(LemmyDialect.handle(fromActorURL:)) ?? entry.creator.name,
                        body: entry.comment.content.trimmingCharacters(in: .whitespacesAndNewlines),
                        createdDate: JSONCommentsFetching.date(entry.comment.published),
                        sourceURL: entry.comment.apID
                    )
                }
        }
        return []
    }
}
