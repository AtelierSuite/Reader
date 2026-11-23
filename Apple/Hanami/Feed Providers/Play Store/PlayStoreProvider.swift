import Foundation

public final class PlayStoreProvider: Sendable {

    public nonisolated static let appScheme = "playstore-app"
    public nonisolated static let developerScheme = "playstore-developer"
    nonisolated static let refreshInterval: TimeInterval = 60 * 60

    nonisolated private static let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        + "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    public nonisolated static var defaultCountry: String {
        Locale.current.region?.identifier.lowercased() ?? "us"
    }

    public nonisolated static var defaultLanguage: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    public func fetchHTML(for target: PlayStoreFeedTarget) async throws -> String {
        guard let url = target.fetchURL else { throw URLError(.badURL) }
        var request = URLRequest.sakura(url: url)
        request.setValue(Self.desktopUserAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        return html
    }

    public func fetchAppDetails(for target: PlayStoreFeedTarget) async throws -> PlayStoreAppDetails {
        let html = try await fetchHTML(for: target)
        guard let details = Self.parseAppDetails(from: html, packageIdentifier: target.identifier) else {
            throw URLError(.cannotParseResponse)
        }
        return details
    }

    public func fetchDeveloperPage(for target: PlayStoreFeedTarget) async throws -> PlayStoreDeveloperPage {
        let html = try await fetchHTML(for: target)
        let fallbackName = target.kind == .developerNamed ? target.identifier : nil
        return Self.parseDeveloperPage(from: html, fallbackName: fallbackName)
    }
}
