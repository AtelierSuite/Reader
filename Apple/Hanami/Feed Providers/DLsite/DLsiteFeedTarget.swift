import Foundation

public nonisolated struct DLsiteFeedTarget: Sendable, Equatable {

    public enum Source: Sendable, Equatable {
        case circle(String)
        case series(String)
        case creator(String)
    }

    public let shop: DLsiteShop
    public let source: Source

    public init(shop: DLsiteShop, source: Source) {
        self.shop = shop
        self.source = source
    }

    public var feedURL: String {
        switch source {
        case .circle(let makerID): "\(DLsiteProvider.circleScheme)://\(shop.rawValue)/\(makerID)"
        case .series(let titleID): "\(DLsiteProvider.seriesScheme)://\(shop.rawValue)/\(titleID)"
        case .creator(let name):
            "\(DLsiteProvider.creatorScheme)://\(shop.rawValue)/\(DLsiteProvider.encodedPathSegment(name))"
        }
    }

    public var siteURL: String {
        let shopURL = "\(DLsiteProvider.origin)/\(shop.rawValue)"
        return switch source {
        case .circle(let makerID): "\(shopURL)/circle/profile/=/maker_id/\(makerID).html"
        case .series(let titleID): "\(shopURL)/fsr/=/title_id/\(titleID)"
        case .creator(let name): "\(shopURL)/fsr/=/keyword_creater/\(DLsiteProvider.quotedKeyword(name))"
        }
    }

    var listFilterPath: String {
        switch source {
        case .circle(let makerID): "maker_ids%5B0%5D/\(makerID)"
        case .series(let titleID): "title_id/\(titleID)"
        case .creator(let name): "keyword_creater/\(DLsiteProvider.quotedKeyword(name))"
        }
    }

    public init?(feedURL: String) {
        guard let separator = feedURL.range(of: "://") else { return nil }
        let scheme = String(feedURL[..<separator.lowerBound])
        let parts = feedURL[separator.upperBound...].split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2, let shop = DLsiteShop(rawValue: parts[0]) else { return nil }
        let value = parts[1]
        switch scheme {
        case DLsiteProvider.circleScheme:
            guard Self.isID(value, prefix: "RG") else { return nil }
            self.init(shop: shop, source: .circle(value))
        case DLsiteProvider.seriesScheme:
            guard Self.isID(value, prefix: "SRI") else { return nil }
            self.init(shop: shop, source: .series(value))
        case DLsiteProvider.creatorScheme:
            guard let name = value.removingPercentEncoding, !name.isEmpty else { return nil }
            self.init(shop: shop, source: .creator(name))
        default:
            return nil
        }
    }

    static func isID(_ value: String, prefix: String) -> Bool {
        value.hasPrefix(prefix) && value.count > prefix.count
            && value.dropFirst(prefix.count).allSatisfy(\.isNumber)
    }
}
