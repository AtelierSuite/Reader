import Foundation
import WebKit

/// Follows DLsite circles, series and creators through the store's search and product info endpoints.
public final class DLsiteProvider: Sendable {

    public nonisolated static let circleScheme = "dlsite-circle"
    public nonisolated static let seriesScheme = "dlsite-series"
    public nonisolated static let creatorScheme = "dlsite-creator"
    public nonisolated static let schemes = [circleScheme, seriesScheme, creatorScheme]

    public nonisolated static let origin = "https://www.dlsite.com"

    nonisolated static let worksPerRefresh = 30
    nonisolated static let descriptionsPerRefresh = 8

    public nonisolated static func isWebHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "dlsite.com" || host == "www.dlsite.com"
    }

    nonisolated static func isProductID(_ value: String) -> Bool {
        value.count > 2 && value.prefix(2).allSatisfy { $0.isASCII && $0.isUppercase }
            && value.dropFirst(2).allSatisfy(\.isNumber)
    }

    nonisolated static func encodedPathSegment(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#\"")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    nonisolated static func quotedKeyword(_ value: String) -> String {
        encodedPathSegment("\"\(value)\"")
    }

    nonisolated static func absoluteImageURL(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value.hasPrefix("//") ? "https:\(value)" : value
    }

    nonisolated static func workPageURL(shop: DLsiteShop, productID: String) -> String {
        "\(origin)/\(shop.rawValue)/work/=/product_id/\(productID).html"
    }

    @MainActor
    static func hasAdultContentCookie() async -> Bool {
        let expected = AdultContentGate.cookie(for: .dlsite)
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        return cookies.contains { cookie in
            cookie.name == expected.name && cookie.value == expected.value
                && cookie.domain.lowercased().hasSuffix("dlsite.com")
        }
    }

    nonisolated static func fetchData(
        percentEncodedPath: String, queryItems: [URLQueryItem] = [], includesAdultContent: Bool
    ) async throws -> Data {
        guard var components = URLComponents(string: origin) else { throw URLError(.badURL) }
        components.percentEncodedPath = percentEncodedPath
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest.sakura(url: url, timeoutInterval: 20)
        request.setValue("ja", forHTTPHeaderField: "Accept-Language")
        request.setValue("\(origin)/", forHTTPHeaderField: "Referer")
        if includesAdultContent {
            let cookie = AdultContentGate.cookie(for: .dlsite)
            request.setValue("\(cookie.name)=\(cookie.value)", forHTTPHeaderField: "Cookie")
        }
        request.httpShouldHandleCookies = false
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw DLsiteFetchError.unavailable }
        return data
    }
}

nonisolated enum DLsiteFetchError: Error {
    case unavailable
}
