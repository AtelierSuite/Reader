import Foundation

extension BlueskyProvider {

    nonisolated static let postPageLimit = 50
    nonisolated static let firstFetchPageCount = 3
    nonisolated static let appViewProxyHeader = "did:web:api.bsky.app#bsky_appview"

    nonisolated static func xrpc(
        _ method: String,
        query: [URLQueryItem],
        requireAuth: Bool = false,
        useAppViewProxy: Bool = true,
        includeLabelers: Bool = true
    ) async throws -> [String: Any] {
        if let session = await BlueskySessionCoordinator.shared.validSession() {
            let labelers = includeLabelers ? await BlueskyPreferencesCache.shared.labelerHeaderValue() : nil
            return try await authenticatedXRPC(
                method,
                query: query,
                session: session,
                useAppViewProxy: useAppViewProxy,
                labelers: labelers,
                allowRefreshRetry: true
            )
        }
        if requireAuth {
            throw BlueskyAPIError.authenticationRequired
        }
        return try await publicXRPC(method, query: query)
    }

    nonisolated static func fetchPostPages(
        _ method: String,
        query: [URLQueryItem],
        pageCount: Int,
        requireAuth: Bool = false
    ) async throws -> [ParsedBlueskyPost] {
        let preferences = await BlueskyPreferencesCache.shared.currentPreferences()
        var posts: [ParsedBlueskyPost] = []
        var cursor: String?
        for pageIndex in 0..<max(pageCount, 1) {
            var pageQuery = query + [URLQueryItem(name: "limit", value: String(postPageLimit))]
            if let cursor { pageQuery.append(URLQueryItem(name: "cursor", value: cursor)) }
            let root: [String: Any]
            do {
                root = try await xrpc(method, query: pageQuery, requireAuth: requireAuth)
            } catch where pageIndex > 0 {
                log("BlueskyFeed", "\(method) page \(pageIndex) failed - \(error.localizedDescription)")
                break
            }
            let entries = (root["feed"] as? [[String: Any]]) ?? []
            posts += entries.compactMap { parseFeedViewPost($0, preferences: preferences) }
            guard let nextCursor = root["cursor"] as? String, !nextCursor.isEmpty,
                  nextCursor != cursor, !entries.isEmpty else { break }
            cursor = nextCursor
        }
        var seenURIs = Set<String>()
        return posts.filter { seenURIs.insert($0.uri).inserted }
    }

    private nonisolated static func authenticatedXRPC(
        _ method: String,
        query: [URLQueryItem],
        session: BlueskySession,
        useAppViewProxy: Bool,
        labelers: String?,
        allowRefreshRetry: Bool
    ) async throws -> [String: Any] {
        guard var components = URLComponents(string: "\(session.pdsEndpoint)/xrpc/\(method)") else {
            throw URLError(.badURL)
        }
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        if useAppViewProxy {
            request.setValue(appViewProxyHeader, forHTTPHeaderField: "atproto-proxy")
        }
        if let labelers, !labelers.isEmpty {
            request.setValue(labelers, forHTTPHeaderField: "atproto-accept-labelers")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if status == 200, let root { return root }

        let errorCode = root?["error"] as? String
        if allowRefreshRetry, (status == 400 || status == 401), errorCode == "ExpiredToken" {
            let refreshed = try await BlueskySessionCoordinator.shared.refreshSession()
            return try await authenticatedXRPC(
                method,
                query: query,
                session: refreshed,
                useAppViewProxy: useAppViewProxy,
                labelers: labelers,
                allowRefreshRetry: false
            )
        }
        if status == 401 || errorCode == "AuthRequiredError" {
            throw BlueskyAPIError.authenticationRequired
        }
        throw BlueskyAPIError.requestFailed(status: status, message: root?["message"] as? String)
    }

    private nonisolated static func publicXRPC(
        _ method: String,
        query: [URLQueryItem]
    ) async throws -> [String: Any] {
        guard var components = URLComponents(string: "https://\(publicAPIHost)/xrpc/\(method)") else {
            throw URLError(.badURL)
        }
        components.queryItems = query.isEmpty ? nil : query
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
}
