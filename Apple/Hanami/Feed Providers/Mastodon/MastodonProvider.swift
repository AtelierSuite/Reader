import Foundation

public nonisolated enum MastodonProvider: FeedProvider {

    public static var providerID: String { "mastodon-timeline" }

    public static var domains: Set<String> { [] }

    public static func matchesFeedURL(_ feedURL: String) -> Bool {
        isFeedURL(feedURL)
    }

    public static func isFeedURL(_ url: String) -> Bool {
        MastodonFeedTarget.isFeedURL(url)
    }

    public static func inferredSiteURL(fromFeedURL feedURL: String) -> String? {
        MastodonFeedTarget(feedURL: feedURL)?.siteURL
    }

    public static func profileURL(fromStatusURL url: URL) -> URL? {
        guard let host = url.host?.lowercased(), !host.isEmpty else { return nil }
        let components = url.pathComponents
        guard components.count >= 2, components[1].hasPrefix("@"), components[1].count > 1 else {
            return nil
        }
        return URL(string: "https://\(host)/\(components[1])")
    }

    static func fetchInstance(host: String) async -> MastodonInstance? {
        for path in ["/api/v2/instance", "/api/v1/instance"] {
            guard let url = URL(string: "https://\(host)\(path)") else { continue }
            var request = URLRequest.sakura(url: url, timeoutInterval: 6)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let instance = try? JSONDecoder().decode(MastodonInstance.self, from: data),
                  instance.displayTitle != nil || instance.domain != nil else {
                continue
            }
            return instance
        }
        return nil
    }

    static func fetchTimeline(
        target: MastodonFeedTarget,
        limit: Int = 40
    ) async throws -> [MastodonStatus] {
        guard let url = target.timelineAPIURL(limit: limit) else {
            throw URLError(.badURL)
        }
        var request = URLRequest.sakura(url: url, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([MastodonStatus].self, from: data)
    }
}
