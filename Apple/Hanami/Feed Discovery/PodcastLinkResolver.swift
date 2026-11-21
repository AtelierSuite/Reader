import Foundation

/// Resolves share links from Apple Podcasts and other podcast apps to the show's RSS feed.
public nonisolated enum PodcastLinkResolver {

    public struct ShowReference: Sendable, Equatable {
        public let showID: String
        public let storefront: String?
    }

    public static func showReference(for url: URL) -> ShowReference? {
        guard let host = url.host?.lowercased() else { return nil }
        let segments = url.path.split(separator: "/").map { $0.lowercased() }
        switch host {
        case "podcasts.apple.com", "itunes.apple.com":
            guard segments.contains("podcast"),
                  let showID = segments.lazy.compactMap({ digits(in: $0, afterPrefix: "id") }).first else {
                return nil
            }
            let storefront = segments.first.flatMap { $0.count == 2 && $0.allSatisfy(\.isLetter) ? $0 : nil }
            return ShowReference(showID: showID, storefront: storefront)
        case "overcast.fm":
            return segments.first
                .flatMap { digits(in: $0, afterPrefix: "itunes") }
                .map { ShowReference(showID: $0, storefront: nil) }
        case "castro.fm", "pca.st":
            guard segments.count >= 2, segments[0] == "itunes",
                  let showID = digits(in: segments[1], afterPrefix: "") else { return nil }
            return ShowReference(showID: showID, storefront: nil)
        default:
            return nil
        }
    }

    public static func discoveredFeed(for url: URL) async -> DiscoveredFeed? {
        guard let reference = showReference(for: url) else { return nil }
        var show = await lookup(showID: reference.showID, storefront: nil)
        if show == nil, let storefront = reference.storefront {
            show = await lookup(showID: reference.showID, storefront: storefront)
        }
        let storefront = reference.storefront ?? "us"
        let showPage = "https://podcasts.apple.com/\(storefront)/podcast/id\(reference.showID)"
        var feedURL = show?.feedUrl
        if feedURL == nil {
            feedURL = await feedURLFromShowPage(showPage, showID: reference.showID)
        }
        guard let feedURL, !feedURL.isEmpty else { return nil }
        return DiscoveredFeed(
            title: show?.collectionName ?? "Podcast",
            url: feedURL,
            siteURL: show?.collectionViewUrl ?? showPage
        )
    }

    private static func digits(in segment: String, afterPrefix prefix: String) -> String? {
        guard segment.hasPrefix(prefix) else { return nil }
        let rest = segment.dropFirst(prefix.count)
        return !rest.isEmpty && rest.allSatisfy(\.isNumber) ? String(rest) : nil
    }
}
