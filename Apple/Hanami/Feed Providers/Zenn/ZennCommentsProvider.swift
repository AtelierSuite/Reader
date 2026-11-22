import Foundation

public nonisolated enum ZennCommentsProvider {

    static func articleSlug(from url: URL) -> String? {
        guard let host = url.host?.lowercased(), host == "zenn.dev" || host == "www.zenn.dev" else { return nil }
        let components = url.pathComponents
        guard components.count == 4, components[2] == "articles" else { return nil }
        return components[3]
    }

    struct Response: Decodable {
        let article: ArticlePayload
    }

    struct ArticlePayload: Decodable {
        let comments: [Comment]?
    }

    struct Comment: Decodable {
        let bodyHTML: String?
        let createdAt: String?
        let user: User?

        enum CodingKeys: String, CodingKey {
            case user
            case bodyHTML = "body_html"
            case createdAt = "created_at"
        }
    }

    struct User: Decodable {
        let name: String?
        let username: String?
    }
}

extension ZennCommentsProvider: FeedProvider {

    public nonisolated static var providerID: String { "zenn" }

    public nonisolated static var domains: Set<String> { [] }

    public nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool { false }
}

extension ZennCommentsProvider: CommentsProvider {

    public nonisolated static func canProvideComments(for article: Article, in feed: Feed?) -> Bool {
        commentsURL(for: article, in: feed) != nil
    }

    public nonisolated static func commentsURL(for article: Article, in _: Feed?) -> URL? {
        guard let url = URL(string: article.url), articleSlug(from: url) != nil else { return nil }
        return url
    }

    public static func fetchComments(
        for article: Article, in feed: Feed?, limit: Int
    ) async throws -> [FetchedComment] {
        guard limit > 0, let articleURL = commentsURL(for: article, in: feed),
              let slug = articleSlug(from: articleURL),
              let apiURL = URL(string: "https://zenn.dev/api/articles/\(slug)"),
              let response = try await JSONCommentsFetching.decode(
                Response.self, from: .sakura(url: apiURL), source: "Zenn"
              ) else { return [] }
        return (response.article.comments ?? []).prefix(limit).compactMap { comment in
            let body = MastodonCommentsProvider.cleanCommentText(comment.bodyHTML ?? "")
            guard !body.isEmpty else { return nil }
            return FetchedComment(
                author: comment.user?.name ?? comment.user?.username ?? "",
                body: body,
                createdDate: JSONCommentsFetching.date(comment.createdAt),
                sourceURL: articleURL.absoluteString
            )
        }
    }
}
