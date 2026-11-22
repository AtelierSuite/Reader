import Foundation

public nonisolated struct DMMFeedTarget: Sendable, Equatable {

    public enum Shop: String, Sendable {
        case general
        case adult

        public var booksHost: String {
            switch self {
            case .general: "book.dmm.com"
            case .adult: "book.dmm.co.jp"
            }
        }

        init?(booksHost host: String) {
            switch host.lowercased() {
            case "book.dmm.com": self = .general
            case "book.dmm.co.jp": self = .adult
            default: return nil
            }
        }
    }

    public enum Source: Sendable, Equatable {
        case bookSeries(Shop, String)
        case bookAuthor(Shop, String)
        case doujinCircle(String)
        case doujinSeries(String)
    }

    public let source: Source

    public init(source: Source) {
        self.source = source
    }

    public var isAdult: Bool {
        switch source {
        case .bookSeries(let shop, _), .bookAuthor(let shop, _): shop == .adult
        case .doujinCircle, .doujinSeries: true
        }
    }

    public var feedURL: String {
        switch source {
        case .bookSeries(let shop, let seriesID): "\(DMMProvider.bookSeriesScheme)://\(shop.rawValue)/\(seriesID)"
        case .bookAuthor(let shop, let authorID): "\(DMMProvider.bookAuthorScheme)://\(shop.rawValue)/\(authorID)"
        case .doujinCircle(let circleID): "\(DMMProvider.doujinCircleScheme)://\(circleID)"
        case .doujinSeries(let seriesID): "\(DMMProvider.doujinSeriesScheme)://\(seriesID)"
        }
    }

    public var siteURL: String {
        switch source {
        case .bookSeries(let shop, let seriesID): "https://\(shop.booksHost)/product/\(seriesID)/volumes/"
        case .bookAuthor(let shop, let authorID): "https://\(shop.booksHost)/list/?author=\(authorID)"
        case .doujinCircle(let circleID): DMMProvider.doujinListURL(article: "maker", identifier: circleID)
        case .doujinSeries(let seriesID): DMMProvider.doujinListURL(article: "series", identifier: seriesID)
        }
    }

    public init?(feedURL: String) {
        guard let separator = feedURL.range(of: "://") else { return nil }
        let scheme = String(feedURL[..<separator.lowerBound])
        let parts = feedURL[separator.upperBound...].split(separator: "/").map(String.init)
        switch scheme {
        case DMMProvider.bookSeriesScheme, DMMProvider.bookAuthorScheme:
            guard parts.count == 2, let shop = Shop(rawValue: parts[0]), Self.isNumericID(parts[1]) else {
                return nil
            }
            self.init(source: scheme == DMMProvider.bookSeriesScheme
                      ? .bookSeries(shop, parts[1]) : .bookAuthor(shop, parts[1]))
        case DMMProvider.doujinCircleScheme, DMMProvider.doujinSeriesScheme:
            guard parts.count == 1, Self.isNumericID(parts[0]) else { return nil }
            self.init(source: scheme == DMMProvider.doujinCircleScheme
                      ? .doujinCircle(parts[0]) : .doujinSeries(parts[0]))
        default:
            return nil
        }
    }

    public init?(pageURL: URL) {
        guard let host = pageURL.host?.lowercased() else { return nil }
        let segments = pageURL.path.split(separator: "/").map(String.init)
        if let shop = Shop(booksHost: host) {
            if segments.count >= 2, segments[0] == "product", Self.isNumericID(segments[1]) {
                self.init(source: .bookSeries(shop, segments[1]))
                return
            }
            let queryItems = URLComponents(url: pageURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
            if segments.first == "list",
               let authorID = queryItems.first(where: { $0.name == "author" })?.value,
               Self.isNumericID(authorID) {
                self.init(source: .bookAuthor(shop, authorID))
                return
            }
            return nil
        }
        guard DMMProvider.isDoujinHost(host),
              let (article, identifier) = DMMProvider.doujinListArticle(in: pageURL) else { return nil }
        switch article {
        case "maker": self.init(source: .doujinCircle(identifier))
        case "series": self.init(source: .doujinSeries(identifier))
        default: return nil
        }
    }

    static func isNumericID(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy(\.isASCII) && value.allSatisfy(\.isNumber)
    }
}
