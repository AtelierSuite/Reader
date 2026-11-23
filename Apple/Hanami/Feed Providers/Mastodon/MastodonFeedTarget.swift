import Foundation

public nonisolated struct MastodonFeedTarget: Sendable, Equatable {

    public enum Scope: String, Sendable, CaseIterable {
        case local
        case federated
    }

    public static let scheme = "mastodon-timeline"

    public let host: String
    public let scope: Scope

    public init(host: String, scope: Scope) {
        self.host = host.lowercased()
        self.scope = scope
    }

    public var feedURL: String {
        "\(Self.scheme)://\(host)/\(scope.rawValue)"
    }

    public var siteURL: String {
        switch scope {
        case .local: "https://\(host)/public/local"
        case .federated: "https://\(host)/public"
        }
    }

    public func timelineAPIURL(limit: Int = 40) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/api/v1/timelines/public"
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if scope == .local {
            queryItems.append(URLQueryItem(name: "local", value: "true"))
        }
        components.queryItems = queryItems
        return components.url
    }

    public static func isFeedURL(_ url: String) -> Bool {
        url.hasPrefix(scheme + "://")
    }

    public init?(feedURL: String) {
        guard let components = URLComponents(string: feedURL),
              components.scheme == Self.scheme,
              let host = components.host?.lowercased(), !host.isEmpty else {
            return nil
        }
        let segments = components.path.split(separator: "/").map(String.init)
        guard segments.count == 1, let scope = Scope(rawValue: segments[0]) else {
            return nil
        }
        self.init(host: host, scope: scope)
    }
}
