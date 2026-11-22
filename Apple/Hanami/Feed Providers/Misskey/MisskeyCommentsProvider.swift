import Foundation

public nonisolated enum MisskeyCommentsProvider {

    static func noteID(from url: URL) -> String? {
        let components = url.pathComponents
        guard components.count == 3, components[1] == "notes",
              components[2].allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return components[2]
    }

    struct Note: Decodable {
        let id: String
        let text: String?
        let cw: String? // swiftlint:disable:this identifier_name
        let createdAt: String?
        let user: User?
    }

    struct User: Decodable {
        let name: String?
        let username: String?
        let host: String?
    }
}

extension MisskeyCommentsProvider: FeedProvider {

    public nonisolated static var providerID: String { "misskey" }

    public nonisolated static var domains: Set<String> { [] }

    public nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool { false }
}

extension MisskeyCommentsProvider: CommentsProvider {

    public nonisolated static func canProvideComments(for article: Article, in feed: Feed?) -> Bool {
        commentsURL(for: article, in: feed) != nil
    }

    public nonisolated static func commentsURL(for article: Article, in feed: Feed?) -> URL? {
        guard let feed, feed.isFediverseFeed, let url = URL(string: article.url), noteID(from: url) != nil else {
            return nil
        }
        return url
    }

    public static func fetchComments(
        for article: Article, in feed: Feed?, limit: Int
    ) async throws -> [FetchedComment] {
        guard limit > 0, let noteURL = commentsURL(for: article, in: feed), let host = noteURL.host,
              let noteID = noteID(from: noteURL),
              let apiURL = URL(string: "https://\(host)/api/notes/replies") else { return [] }
        var request = URLRequest.sakura(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["noteId": noteID, "limit": limit])
        guard let replies = try await JSONCommentsFetching.decode(
            [Note].self, from: request, source: "Misskey"
        ) else { return [] }
        return replies.prefix(limit).compactMap { reply in
            let text = MisskeyDialect.withoutCustomEmoji(reply.cw.map { "CW: \($0)" } ?? reply.text ?? "")
            guard !text.isEmpty else { return nil }
            let name = MisskeyDialect.withoutCustomEmoji(reply.user?.name ?? "")
            return FetchedComment(
                author: name.isEmpty ? "@\(reply.user?.username ?? "")" : name,
                body: text,
                createdDate: JSONCommentsFetching.date(reply.createdAt),
                sourceURL: "https://\(host)/notes/\(reply.id)"
            )
        }
    }
}
