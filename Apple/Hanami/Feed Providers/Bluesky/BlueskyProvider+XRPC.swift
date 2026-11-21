import Foundation

extension BlueskyProvider {

    nonisolated static let postPageLimit = 50
    nonisolated static let firstFetchPageCount = 3

    nonisolated static func xrpc(_ method: String, query: [URLQueryItem]) async throws -> [String: Any] {
        guard var components = URLComponents(string: "https://\(publicAPIHost)/xrpc/\(method)") else {
            throw URLError(.badURL)
        }
        components.queryItems = query
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if status == 200, let root { return root }
        if status == 401 || (root?["error"] as? String) == "AuthRequiredError" {
            throw BlueskyAPIError.authenticationRequired
        }
        throw BlueskyAPIError.requestFailed(status: status, message: root?["message"] as? String)
    }

    nonisolated static func fetchPostPages(
        _ method: String, query: [URLQueryItem], pageCount: Int
    ) async throws -> [ParsedBlueskyPost] {
        var posts: [ParsedBlueskyPost] = []
        var cursor: String?
        for pageIndex in 0..<max(pageCount, 1) {
            var pageQuery = query + [URLQueryItem(name: "limit", value: String(postPageLimit))]
            if let cursor { pageQuery.append(URLQueryItem(name: "cursor", value: cursor)) }
            let root: [String: Any]
            do {
                root = try await xrpc(method, query: pageQuery)
            } catch where pageIndex > 0 {
                log("BlueskyFeed", "\(method) page \(pageIndex) failed - \(error.localizedDescription)")
                break
            }
            let entries = (root["feed"] as? [[String: Any]]) ?? []
            posts += entries.compactMap { parseFeedViewPost($0) }
            guard let nextCursor = root["cursor"] as? String, !nextCursor.isEmpty,
                  nextCursor != cursor, !entries.isEmpty else { break }
            cursor = nextCursor
        }
        var seenURIs = Set<String>()
        return posts.filter { seenURIs.insert($0.uri).inserted }
    }
}
