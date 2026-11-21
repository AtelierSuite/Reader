import Foundation

/// Turns App Store apps and developers into feeds of version updates.
public final class AppStoreProvider: Sendable {

    public nonisolated static let appScheme = "appstore-app"
    public nonisolated static let developerScheme = "appstore-developer"
    nonisolated static let refreshInterval: TimeInterval = 60 * 60

    public nonisolated static var defaultStorefront: String {
        Locale.current.region?.identifier.lowercased() ?? "us"
    }

    nonisolated static func lookupURL(for target: AppStoreFeedTarget) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        var queryItems = [
            URLQueryItem(name: "id", value: target.identifier),
            URLQueryItem(name: "country", value: target.storefront)
        ]
        if target.kind == .developer {
            queryItems.append(URLQueryItem(name: "entity", value: "software"))
            queryItems.append(URLQueryItem(name: "limit", value: "200"))
        }
        components?.queryItems = queryItems
        return components?.url
    }

    public func lookup(_ target: AppStoreFeedTarget) async throws -> AppStoreLookupResponse {
        guard let url = Self.lookupURL(for: target) else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(for: .sakura(url: url))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AppStoreLookupResponse.self, from: data)
    }
}
