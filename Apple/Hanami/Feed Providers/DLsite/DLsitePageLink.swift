import Foundation

nonisolated enum DLsitePageLink: Sendable, Equatable {
    case feed(DLsiteFeedTarget)
    case work(shop: DLsiteShop, productID: String)

    init?(url: URL) {
        guard DLsiteProvider.isWebHost(url.host) else { return nil }
        let encodedPath = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
        let segments = encodedPath.split(separator: "/").map(String.init)
        guard let first = segments.first, let shop = DLsiteShop(pathSegment: first) else { return nil }
        let parameters = Self.parameters(in: segments)
        if let productID = parameters["product_id"].map(Self.removingHTMLExtension),
           DLsiteProvider.isProductID(productID),
           segments.contains("work") || segments.contains("announce") {
            self = .work(shop: shop, productID: productID)
        } else if segments.contains("circle"), let makerID = parameters["maker_id"].map(Self.removingHTMLExtension),
                  DLsiteFeedTarget.isID(makerID, prefix: "RG") {
            self = .feed(DLsiteFeedTarget(shop: shop, source: .circle(makerID)))
        } else if let titleID = parameters["title_id"], DLsiteFeedTarget.isID(titleID, prefix: "SRI") {
            self = .feed(DLsiteFeedTarget(shop: shop, source: .series(titleID)))
        } else if let keyword = parameters["keyword_creater"],
                  let name = Self.creatorName(fromEncodedKeyword: keyword) {
            self = .feed(DLsiteFeedTarget(shop: shop, source: .creator(name)))
        } else {
            return nil
        }
    }

    private static func parameters(in segments: [String]) -> [String: String] {
        guard let marker = segments.firstIndex(of: "=") else { return [:] }
        let pairs = Array(segments[(marker + 1)...])
        var parameters: [String: String] = [:]
        for index in stride(from: 0, to: pairs.count - 1, by: 2) where parameters[pairs[index]] == nil {
            parameters[pairs[index]] = pairs[index + 1]
        }
        return parameters
    }

    private static func removingHTMLExtension(_ value: String) -> String {
        value.hasSuffix(".html") ? String(value.dropLast(".html".count)) : value
    }

    private static func creatorName(fromEncodedKeyword keyword: String) -> String? {
        let decoded = (keyword.removingPercentEncoding ?? keyword)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"").union(.whitespaces))
        return decoded.isEmpty ? nil : decoded
    }
}
