import Foundation

extension BlueskyProvider {

    nonisolated static let shortLinkHost = "go.bsky.app"

    nonisolated static func isShortLink(_ url: URL) -> Bool {
        let segments = url.pathComponents.filter { $0 != "/" }
        switch url.host?.lowercased() {
        case shortLinkHost:
            return segments.count == 1
        case host, "www.\(host)":
            return segments.count == 2 && segments[0].lowercased() == "starter-pack-short"
        default:
            return false
        }
    }

    nonisolated static func resolveShortLink(_ url: URL) async -> URL? {
        guard let code = url.pathComponents.last,
              let shortURL = URL(string: "https://\(shortLinkHost)/\(code)") else { return nil }
        var request = URLRequest.sakura(url: shortURL, timeoutInterval: 15)
        request.httpMethod = "HEAD"
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let resolvedURL = response.url, !isShortLink(resolvedURL),
              resolvedURL.pathComponents.count > 1 else {
            log("BlueskyFeed", "short link did not resolve: \(url.absoluteString)")
            return nil
        }
        return resolvedURL
    }
}
