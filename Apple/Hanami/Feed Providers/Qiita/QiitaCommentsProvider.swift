import Foundation

public nonisolated enum QiitaCommentsProvider {

    static func itemID(from url: URL) -> String? {
        guard let host = url.host?.lowercased(), host == "qiita.com" || host == "www.qiita.com" else { return nil }
        let components = url.pathComponents
        guard components.count == 4, components[2] == "items" else { return nil }
        return components[3]
    }

    struct Comment: Decodable {
        let renderedBody: String?
        let createdAt: String?
        let user: User?

        enum CodingKeys: String, CodingKey {
            case user
            case renderedBody = "rendered_body"
            case createdAt = "created_at"
        }
    }

    struct User: Decodable {
        let id: String?
        let name: String?
    }
}

extension QiitaCommentsProvider: FeedProvider {

    public nonisolated static var providerID: String { "qiita" }

    public nonisolated static var domains: Set<String> { [] }

    public nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool { false }
}

extension QiitaCommentsProvider: CommentsProvider {

    public nonisolated static func canProvideComments(for article: Article, in feed: Feed?) -> Bool {
        commentsURL(for: article, in: feed) != nil
    }

    public nonisolated static func commentsURL(for article: Article, in _: Feed?) -> URL? {
        guard let url = URL(string: article.url), itemID(from: url) != nil else { return nil }
        return url
    }

    public static func fetchComments(
        for article: Article, in feed: Feed?, limit: Int
    ) async throws -> [FetchedComment] {
        guard limit > 0, let itemURL = commentsURL(for: article, in: feed), let itemID = itemID(from: itemURL),
              let apiURL = URL(string: "https://qiita.com/api/v2/items/\(itemID)/comments"),
              let comments = try await JSONCommentsFetching.decode(
                [Comment].self, from: .sakura(url: apiURL), source: "Qiita"
              ) else { return [] }
        return comments.prefix(limit).compactMap { comment in
            let body = MastodonCommentsProvider.cleanCommentText(comment.renderedBody ?? "")
            guard !body.isEmpty else { return nil }
            let name = comment.user?.name.flatMap { $0.isEmpty ? nil : $0 } ?? comment.user?.id ?? ""
            return FetchedComment(
                author: name,
                body: body,
                createdDate: JSONCommentsFetching.date(comment.createdAt),
                sourceURL: itemURL.absoluteString
            )
        }
    }
}
