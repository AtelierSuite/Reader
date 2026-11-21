import Foundation

public nonisolated struct PixivFeedTarget: Sendable, Equatable {

    public enum Source: Sendable, Equatable {
        case user(String)
        case following
        case tag(String)
        case ranking(String)
    }

    public enum Works: String, Sendable {
        case illustManga
        case novels
    }

    public static let rankingModes: Set<String> = [
        "daily", "weekly", "monthly", "rookie", "original", "daily_ai", "male", "female"
    ]

    public let source: Source
    public let works: Works

    public init(source: Source, works: Works = .illustManga) {
        self.source = source
        self.works = works
    }

    public static let following = PixivFeedTarget(source: .following)

    public var feedURL: String {
        switch source {
        case .user(let userID): "\(PixivProvider.userScheme)://\(userID)?works=\(works.rawValue)"
        case .following: "\(PixivProvider.followingScheme)://"
        case .tag(let tag): "\(PixivProvider.tagScheme)://\(Self.encodedPathSegment(tag))"
        case .ranking(let mode): "\(PixivProvider.rankingScheme)://\(mode)"
        }
    }

    public var siteURL: String {
        switch source {
        case .user(let userID):
            works == .novels
                ? "\(PixivProvider.origin)/users/\(userID)/novels"
                : "\(PixivProvider.origin)/users/\(userID)"
        case .following: "\(PixivProvider.origin)/bookmark_new_illust.php"
        case .tag(let tag): "\(PixivProvider.origin)/tags/\(Self.encodedPathSegment(tag))/artworks"
        case .ranking(let mode): "\(PixivProvider.origin)/ranking.php?mode=\(mode)"
        }
    }

    public init?(feedURL: String) {
        guard let separator = feedURL.range(of: "://") else { return nil }
        let scheme = String(feedURL[..<separator.lowerBound])
        let remainder = feedURL[separator.upperBound...]
        let parts = remainder.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let value = parts.first.map(String.init) ?? ""
        let query = parts.count > 1 ? String(parts[1]) : ""
        switch scheme {
        case PixivProvider.userScheme:
            guard !value.isEmpty, value.allSatisfy(\.isNumber) else { return nil }
            let works = query.contains("works=\(Works.novels.rawValue)") ? Works.novels : .illustManga
            self.init(source: .user(value), works: works)
        case PixivProvider.followingScheme:
            self.init(source: .following)
        case PixivProvider.tagScheme:
            guard let tag = value.removingPercentEncoding, !tag.isEmpty else { return nil }
            self.init(source: .tag(tag))
        case PixivProvider.rankingScheme:
            guard Self.rankingModes.contains(value) else { return nil }
            self.init(source: .ranking(value))
        default:
            return nil
        }
    }

    public init?(pageURL: URL) {
        guard PixivProvider.isWebHost(pageURL.host) else { return nil }
        var segments = PixivFeedTarget.decodedPathSegments(of: pageURL)
        if let first = segments.first, first.count == 2, first.allSatisfy(\.isLetter) {
            segments.removeFirst()
        }
        let queryItems = URLComponents(url: pageURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let queryValue = { (name: String) in queryItems.first { $0.name == name }?.value }
        let target: PixivFeedTarget?
        switch segments.first ?? "" {
        case "users": target = Self.userTarget(segments: segments)
        case "member.php": target = queryValue("id").flatMap { Self.userTarget(segments: ["users", $0]) }
        case "tags": target = Self.tagTarget(segments: segments)
        case "ranking.php": target = Self.rankingTarget(mode: queryValue("mode") ?? "daily")
        case "bookmark_new_illust.php": target = .following
        default: target = nil
        }
        guard let target else { return nil }
        self = target
    }

    private static func userTarget(segments: [String]) -> PixivFeedTarget? {
        guard segments.count >= 2, !segments[1].isEmpty, segments[1].allSatisfy(\.isNumber) else { return nil }
        let works = segments.count > 2 && segments[2] == "novels" ? Works.novels : .illustManga
        return PixivFeedTarget(source: .user(segments[1]), works: works)
    }

    private static func tagTarget(segments: [String]) -> PixivFeedTarget? {
        guard segments.count >= 2, !segments[1].isEmpty,
              segments.count < 3 || segments[2] != "novels" else { return nil }
        return PixivFeedTarget(source: .tag(segments[1]))
    }

    private static func rankingTarget(mode: String) -> PixivFeedTarget? {
        rankingModes.contains(mode) ? PixivFeedTarget(source: .ranking(mode)) : nil
    }

    static func decodedPathSegments(of url: URL) -> [String] {
        let encodedPath = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
        return encodedPath.split(separator: "/").map { segment in
            String(segment).removingPercentEncoding ?? String(segment)
        }
    }

    static func encodedPathSegment(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
