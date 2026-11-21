import Foundation

nonisolated private let podcastServerDataRegex = try? NSRegularExpression(
    pattern: #"<script type="application/json" id="serialized-server-data">(.*?)</script>"#,
    options: .dotMatchesLineSeparators
)

nonisolated private let podcastDesktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5 Safari/605.1.15"

nonisolated extension PodcastLinkResolver {

    struct Show: Decodable, Sendable {
        let kind: String?
        let collectionName: String?
        let collectionViewUrl: String?
        let feedUrl: String?
    }

    private struct LookupResponse: Decodable {
        let results: [Show]
    }

    static func lookup(showID: String, storefront: String?) async -> Show? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [
            URLQueryItem(name: "id", value: showID),
            URLQueryItem(name: "entity", value: "podcast")
        ] + (storefront.map { [URLQueryItem(name: "country", value: $0)] } ?? [])
        guard let url = components?.url,
              let (data, _) = try? await URLSession.shared.data(for: .sakura(url: url)),
              let response = try? JSONDecoder().decode(LookupResponse.self, from: data) else {
            return nil
        }
        return response.results.first { $0.kind == "podcast" }
    }

    /// Apple-owned shows omit `feedUrl` from the lookup API but embed it in the show page.
    static func feedURLFromShowPage(_ page: String, showID: String) async -> String? {
        guard let url = URL(string: page) else { return nil }
        var request = URLRequest.sakura(url: url)
        request.setValue(podcastDesktopUserAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8),
              let regex = podcastServerDataRegex,
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html),
              let root = try? JSONSerialization.jsonObject(with: Data(html[range].utf8)) else {
            return nil
        }
        return feedURL(in: root, showID: showID)
    }

    // The page also lists related shows, so only an entry with the matching ID counts.
    private static func feedURL(in node: Any, showID: String) -> String? {
        if let dictionary = node as? [String: Any] {
            if let feedURL = dictionary["feedUrl"] as? String, !feedURL.isEmpty,
               JSONFeedParser.string(dictionary["adamId"]) == showID {
                return feedURL
            }
            for value in dictionary.values {
                if let found = feedURL(in: value, showID: showID) { return found }
            }
        } else if let array = node as? [Any] {
            for value in array {
                if let found = feedURL(in: value, showID: showID) { return found }
            }
        }
        return nil
    }
}
