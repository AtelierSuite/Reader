import Foundation

public nonisolated struct PixivFeedTarget: Sendable, Equatable {

    public enum Source: Sendable, Equatable {
        case user(String)
        case following
        case tag(String)
        case ranking(String)
        case mangaSeries(seriesID: String, userID: String)
        case novelSeries(String)
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
        case .mangaSeries(let seriesID, let userID): "\(PixivProvider.mangaSeriesScheme)://\(userID)/\(seriesID)"
        case .novelSeries(let seriesID): "\(PixivProvider.novelSeriesScheme)://\(seriesID)"
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
        case .mangaSeries(let seriesID, let userID): "\(PixivProvider.origin)/user/\(userID)/series/\(seriesID)"
        case .novelSeries(let seriesID): "\(PixivProvider.origin)/novel/series/\(seriesID)"
        }
    }

    public init?(feedURL: String) {
        guard let separator = feedURL.range(of: "://") else { return nil }
        let scheme = String(feedURL[..<separator.lowerBound])
        let remainder = feedURL[separator.upperBound...]
        let parts = remainder.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let value = parts.first ?? ""
        let query = parts.dropFirst().first ?? ""
        switch scheme {
        case PixivProvider.userScheme:
            guard Self.isNumericID(value) else { return nil }
            self.init(source: .user(value), works: Self.works(inQuery: query))
        case PixivProvider.followingScheme:
            self.init(source: .following)
        case PixivProvider.tagScheme:
            guard let tag = value.removingPercentEncoding, !tag.isEmpty else { return nil }
            self.init(source: .tag(tag))
        case PixivProvider.rankingScheme:
            guard Self.rankingModes.contains(value) else { return nil }
            self.init(source: .ranking(value))
        default:
            guard let target = Self.seriesTarget(scheme: scheme, value: value) else { return nil }
            self = target
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
        case "user", "novel": target = Self.seriesTarget(segments: segments)
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

    private static func seriesTarget(scheme: String, value: String) -> PixivFeedTarget? {
        let identifiers = value.split(separator: "/").map(String.init)
        guard identifiers.allSatisfy(isNumericID) else { return nil }
        if scheme == PixivProvider.mangaSeriesScheme, identifiers.count == 2 {
            return PixivFeedTarget(source: .mangaSeries(seriesID: identifiers[1], userID: identifiers[0]))
        }
        if scheme == PixivProvider.novelSeriesScheme, identifiers.count == 1 {
            return PixivFeedTarget(source: .novelSeries(identifiers[0]), works: .novels)
        }
        return nil
    }

    private static func seriesTarget(segments: [String]) -> PixivFeedTarget? {
        if segments.count >= 4, segments[0] == "user", segments[2] == "series",
           isNumericID(segments[1]), isNumericID(segments[3]) {
            return PixivFeedTarget(source: .mangaSeries(seriesID: segments[3], userID: segments[1]))
        }
        if segments.count >= 3, segments[0] == "novel", segments[1] == "series", isNumericID(segments[2]) {
            return PixivFeedTarget(source: .novelSeries(segments[2]), works: .novels)
        }
        return nil
    }

    private static func works(inQuery query: String) -> Works {
        query.contains("works=\(Works.novels.rawValue)") ? .novels : .illustManga
    }

    private static func isNumericID(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy(\.isNumber)
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
