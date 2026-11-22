import Foundation

public nonisolated enum HatenaBookmarkCommentsProvider {

    /// `https://example.com/a` is discussed at `b.hatena.ne.jp/entry/s/example.com/a`.
    static func entryPageURL(for articleURL: URL) -> URL? {
        guard let scheme = articleURL.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        let address = articleURL.absoluteString.dropFirst(scheme.count + 3)
        return URL(string: "https://b.hatena.ne.jp/entry/\(scheme == "https" ? "s/" : "")\(address)")
    }

    static func reactionsURL(for articleURL: URL) -> URL? {
        var components = URLComponents(string: "https://b.hatena.ne.jp/api/ipad.entry_reactions")
        components?.queryItems = [URLQueryItem(name: "url", value: articleURL.absoluteString)]
        return components?.url
    }

    struct Reactions: Decodable {
        let scoredBookmarks: [Bookmark]?

        enum CodingKeys: String, CodingKey {
            case scoredBookmarks = "scored_bookmarks"
        }
    }

    struct Bookmark: Decodable {
        let comment: String?
        let timestamp: String?
        let link: String?
        let user: User?
    }

    struct User: Decodable {
        let name: String?
    }
}

extension HatenaBookmarkCommentsProvider: FeedProvider {

    public nonisolated static var providerID: String { "hatenabookmark" }

    public nonisolated static var domains: Set<String> { [] }

    public nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool { false }
}

extension HatenaBookmarkCommentsProvider: CommentsProvider {

    public nonisolated static func canProvideComments(for article: Article, in feed: Feed?) -> Bool {
        commentsURL(for: article, in: feed) != nil
    }

    public nonisolated static func commentsURL(for article: Article, in feed: Feed?) -> URL? {
        guard let feed, URL(string: feed.fetchURL)?.host?.lowercased() == HatenaBookmarkDialect.host,
              let articleURL = URL(string: article.url) else { return nil }
        return entryPageURL(for: articleURL)
    }

    public static func fetchComments(
        for article: Article, in feed: Feed?, limit: Int
    ) async throws -> [FetchedComment] {
        guard limit > 0, commentsURL(for: article, in: feed) != nil,
              let articleURL = URL(string: article.url), let apiURL = reactionsURL(for: articleURL),
              let reactions = try await JSONCommentsFetching.decode(
                Reactions.self, from: .sakura(url: apiURL), source: "HatenaBookmark"
              ) else { return [] }
        return (reactions.scoredBookmarks ?? []).prefix(limit).compactMap { bookmark in
            let body = (bookmark.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return nil }
            return FetchedComment(
                author: bookmark.user?.name ?? "",
                body: body,
                createdDate: JSONCommentsFetching.date(bookmark.timestamp),
                sourceURL: bookmark.link
            )
        }
    }
}
