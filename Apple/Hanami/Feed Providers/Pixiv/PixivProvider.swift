import Foundation

/// Reads pixiv artists, writers, tags and rankings through pixiv's web `/ajax` API.
public final class PixivProvider: Sendable {

    public nonisolated static let userScheme = "pixiv-user"
    public nonisolated static let followingScheme = "pixiv-following"
    public nonisolated static let tagScheme = "pixiv-tag"
    public nonisolated static let rankingScheme = "pixiv-ranking"
    public nonisolated static let mangaSeriesScheme = "pixiv-series"
    public nonisolated static let novelSeriesScheme = "pixiv-novel-series"
    public nonisolated static let schemes = [
        userScheme, followingScheme, tagScheme, rankingScheme, mangaSeriesScheme, novelSeriesScheme
    ]

    public nonisolated static let origin = "https://www.pixiv.net"
    public nonisolated static let showsRestrictedWorksKey = "Pixiv.ShowRestrictedWorks"

    nonisolated static let worksPerRefresh = 48
    nonisolated static let novelsPerRefresh = 20
    nonisolated static let illustDetailLimit = 12

    // pixiv serves its mobile site, and HTML instead of ranking JSON, to the iPhone user agent.
    nonisolated static let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5 Safari/605.1.15"

    public nonisolated static func isWebHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "pixiv.net" || host == "www.pixiv.net"
    }

    nonisolated static func request(percentEncodedPath: String, queryItems: [URLQueryItem] = []) -> URLRequest? {
        guard var components = URLComponents(string: origin) else { return nil }
        components.percentEncodedPath = percentEncodedPath
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { return nil }
        var request = URLRequest.sakura(url: url, timeoutInterval: 20)
        request.setValue(desktopUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("\(origin)/", forHTTPHeaderField: "Referer")
        if let cookieHeader = sessionCookieHeader() {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        request.httpShouldHandleCookies = false
        return request
    }

    nonisolated static func fetchData(
        percentEncodedPath: String, queryItems: [URLQueryItem] = []
    ) async throws -> Data {
        guard let request = request(percentEncodedPath: percentEncodedPath, queryItems: queryItems) else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode == 200 else {
            throw PixivFetchError.unavailable
        }
        return data
    }

    nonisolated static func fetchBody<Body: Decodable & Sendable>(
        _ type: Body.Type, percentEncodedPath: String, queryItems: [URLQueryItem] = []
    ) async throws -> Body {
        let data = try await fetchData(percentEncodedPath: percentEncodedPath, queryItems: queryItems)
        let response = try JSONDecoder().decode(PixivResponse<Body>.self, from: data)
        guard !response.error, let body = response.body else { throw PixivFetchError.unavailable }
        return body
    }
}

nonisolated enum PixivFetchError: Error {
    case unavailable
    case signInRequired
}
