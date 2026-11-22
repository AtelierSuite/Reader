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

    /// Every bookmark on the page, used when none of them has been scored as a popular comment yet.
    static func allBookmarksURL(for articleURL: URL) -> URL? {
        var components = URLComponents(string: "https://b.hatena.ne.jp/entry/jsonlite/")
        components?.queryItems = [URLQueryItem(name: "url", value: articleURL.absoluteString)]
        return components?.url
    }

    static let listedTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    struct Entry: Decodable {
        let bookmarks: [ListedBookmark]?
    }

    struct ListedBookmark: Decodable {
        let user: String?
        let comment: String?
        let timestamp: String?
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
        guard limit > 0, let entryPage = commentsURL(for: article, in: feed),
              let articleURL = URL(string: article.url), let apiURL = reactionsURL(for: articleURL) else { return [] }
        let reactions = try await JSONCommentsFetching.decode(
            Reactions.self, from: .sakura(url: apiURL), source: "HatenaBookmark"
        )
        let popular = (reactions?.scoredBookmarks ?? []).compactMap { bookmark -> FetchedComment? in
            let body = (bookmark.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return nil }
            return FetchedComment(
                author: bookmark.user?.name ?? "",
                body: body,
                createdDate: JSONCommentsFetching.date(bookmark.timestamp),
                sourceURL: bookmark.link
            )
        }
        guard popular.isEmpty else { return Array(popular.prefix(limit)) }
        return try await listedComments(for: articleURL, entryPage: entryPage, limit: limit)
    }

    private static func listedComments(
        for articleURL: URL, entryPage: URL, limit: Int
    ) async throws -> [FetchedComment] {
        guard let listURL = allBookmarksURL(for: articleURL),
              let entry = try await JSONCommentsFetching.decode(
                Entry.self, from: .sakura(url: listURL), source: "HatenaBookmark"
              ) else { return [] }
        let comments = (entry.bookmarks ?? []).compactMap { bookmark -> FetchedComment? in
            let body = (bookmark.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return nil }
            return FetchedComment(
                author: bookmark.user ?? "",
                body: body,
                createdDate: bookmark.timestamp.flatMap(listedTimestampFormatter.date(from:)),
                sourceURL: entryPage.absoluteString
            )
        }
        return Array(comments.prefix(limit))
    }
}
