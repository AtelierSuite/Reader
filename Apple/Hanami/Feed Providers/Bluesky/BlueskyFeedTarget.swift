import Foundation

public nonisolated struct BlueskyFeedTarget: Sendable, Equatable {

    public enum Kind: String, Sendable, CaseIterable {
        case following
        case feed
        case list
        case starterPack

        var scheme: String {
            switch self {
            case .following: "bluesky-following"
            case .feed: "bluesky-feed"
            case .list: "bluesky-list"
            case .starterPack: "bluesky-starterpack"
            }
        }

        var collection: String {
            switch self {
            case .following: ""
            case .feed: "app.bsky.feed.generator"
            case .list: "app.bsky.graph.list"
            case .starterPack: "app.bsky.graph.starterpack"
            }
        }
    }

    public static let following = BlueskyFeedTarget(
        kind: .following, actor: "me", recordKey: "following"
    )

    public let kind: Kind
    public let actor: String
    public let recordKey: String

    public init(kind: Kind, actor: String, recordKey: String) {
        self.kind = kind
        self.actor = actor
        self.recordKey = recordKey
    }

    public init?(atURI: String) {
        guard atURI.hasPrefix("at://") else { return nil }
        let segments = atURI.dropFirst("at://".count).split(separator: "/").map(String.init)
        guard segments.count == 3,
              !segments[0].isEmpty,
              !segments[2].isEmpty,
              let kind = Kind.allCases.first(where: { !$0.collection.isEmpty && $0.collection == segments[1] }) else {
            return nil
        }
        self.init(kind: kind, actor: segments[0], recordKey: segments[2])
    }

    public var feedURL: String {
        "\(kind.scheme)://\(BlueskyProvider.host)/\(actor)/\(recordKey)"
    }

    public var atURI: String {
        "at://\(actor)/\(kind.collection)/\(recordKey)"
    }

    public var siteURL: String {
        let origin = "https://\(BlueskyProvider.host)"
        switch kind {
        case .following: return origin
        case .feed: return "\(origin)/profile/\(actor)/feed/\(recordKey)"
        case .list: return "\(origin)/profile/\(actor)/lists/\(recordKey)"
        case .starterPack: return "\(origin)/starter-pack/\(actor)/\(recordKey)"
        }
    }

    public static func isFeedURL(_ url: String) -> Bool {
        Kind.allCases.contains { url.hasPrefix($0.scheme + "://") }
    }

    public init?(feedURL: String) {
        guard let separator = feedURL.range(of: "://"),
              let kind = Kind.allCases.first(where: { $0.scheme == feedURL[..<separator.lowerBound] }) else {
            return nil
        }
        let segments = feedURL[separator.upperBound...].split(separator: "/").map(String.init)
        guard segments.count == 3, segments[0] == BlueskyProvider.host,
              !segments[1].isEmpty, !segments[2].isEmpty else { return nil }
        self.init(kind: kind, actor: segments[1], recordKey: segments[2])
    }

    public init?(pageURL: URL) {
        guard let host = pageURL.host?.lowercased(),
              host == BlueskyProvider.host || host == "www.\(BlueskyProvider.host)" else { return nil }
        let segments = pageURL.pathComponents.filter { $0 != "/" }
        switch segments.first?.lowercased() {
        case "profile":
            guard segments.count >= 4 else { return nil }
            switch segments[2].lowercased() {
            case "feed": self.init(kind: .feed, actor: segments[1], recordKey: segments[3])
            case "lists": self.init(kind: .list, actor: segments[1], recordKey: segments[3])
            default: return nil
            }
        case "starter-pack", "start":
            guard segments.count >= 3 else { return nil }
            self.init(kind: .starterPack, actor: segments[1], recordKey: segments[2])
        default:
            return nil
        }
        guard BlueskyProvider.isValidHandle(actor), !recordKey.isEmpty else { return nil }
    }

    func withActor(_ actor: String) -> BlueskyFeedTarget {
        BlueskyFeedTarget(kind: kind, actor: actor, recordKey: recordKey)
    }
}
