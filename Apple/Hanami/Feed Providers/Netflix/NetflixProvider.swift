import Foundation

/// Follows Netflix shows through the logged-out title page, adding new episodes as they appear.
public final class NetflixProvider: Sendable {

    public nonisolated static let showScheme = "netflix-show"
    public nonisolated static let origin = "https://www.netflix.com"
    nonisolated static let refreshInterval: TimeInterval = 60 * 60

    public nonisolated static func isWebHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "netflix.com" || host.hasSuffix(".netflix.com")
    }

    /// Title, watch and `?jbv=` links all carry a video ID; episode and season IDs resolve to their show's page.
    nonisolated static func videoID(fromPageURL url: URL) -> String? {
        guard isWebHost(url.host) else { return nil }
        let segments = url.pathComponents.filter { $0 != "/" }
        if let marker = segments.firstIndex(where: { $0 == "title" || $0 == "watch" }),
           marker + 1 < segments.count, isVideoID(segments[marker + 1]) {
            return segments[marker + 1]
        }
        let jumpBackID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "jbv" }?.value
        return jumpBackID.flatMap { isVideoID($0) ? $0 : nil }
    }

    nonisolated static func isVideoID(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 12 && value.allSatisfy(\.isASCII) && value.allSatisfy(\.isNumber)
    }

    nonisolated static func feedURL(forShowID showID: String) -> String {
        "\(showScheme)://\(showID)"
    }

    nonisolated static func showID(fromFeedURL feedURL: String) -> String? {
        guard feedURL.hasPrefix(showScheme + "://") else { return nil }
        let showID = String(feedURL.dropFirst(showScheme.count + 3))
        return isVideoID(showID) ? showID : nil
    }

    nonisolated static func titlePageURL(for videoID: String) -> String {
        "\(origin)/title/\(videoID)"
    }

    nonisolated static func watchURL(for episodeID: String) -> String {
        "\(origin)/watch/\(episodeID)"
    }

    nonisolated static func fetchShow(videoID: String) async throws -> NetflixShow {
        guard let url = URL(string: titlePageURL(for: videoID)) else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(for: .sakura(url: url, timeoutInterval: 20))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw NetflixFetchError.unavailable }
        guard let html = String(data: data, encoding: .utf8),
              let show = NetflixPageData.show(fromTitlePageHTML: html) else { throw NetflixFetchError.notAShow }
        return show
    }
}

nonisolated enum NetflixFetchError: Error {
    case unavailable
    case notAShow
}
