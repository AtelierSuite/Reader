import Foundation

nonisolated extension DLsiteProvider {

    static func fetchListedWorks(
        for target: DLsiteFeedTarget, includesAdultContent: Bool
    ) async throws -> [DLsiteListedWork] {
        let path = "/\(target.shop.rawValue)/fsr/ajax/=/\(target.listFilterPath)"
            + "/order/release_d/per_page/\(worksPerRefresh)"
        let data = try await fetchData(percentEncodedPath: path, includesAdultContent: includesAdultContent)
        let response = try JSONDecoder().decode(DLsiteSearchResponse.self, from: data)
        return DLsiteListedWork.parseSearchResult(response.searchResult)
    }

    static func fetchWorkInfo(
        _ productIDs: [String], shop: DLsiteShop, includesAdultContent: Bool
    ) async throws -> [String: DLsiteWorkInfo] {
        guard !productIDs.isEmpty else { return [:] }
        let data = try await fetchData(
            percentEncodedPath: "/\(shop.rawValue)/product/info/ajax",
            queryItems: [URLQueryItem(name: "product_id", value: productIDs.joined(separator: ","))],
            includesAdultContent: includesAdultContent
        )
        let entries = try JSONDecoder().decode([String: DLsiteWorkInfoEntry].self, from: data)
        return entries.compactMapValues(\.info)
    }

    static func fetchCircleName(_ makerID: String, shop: DLsiteShop) async -> String? {
        guard let data = try? await fetchData(
            percentEncodedPath: "/\(shop.rawValue)/circle/profile/=/maker_id/\(makerID).html",
            includesAdultContent: shop.requiresAdultContentGate
        ), let html = String(data: data, encoding: .utf8) else { return nil }
        return circleName(fromProfileHTML: html)
    }

    static func circleName(fromProfileHTML html: String) -> String? {
        guard let start = html.range(of: "<title>"),
              let end = html.range(of: "</title>", range: start.upperBound..<html.endIndex) else { return nil }
        var title = RSSParser.decodeHTMLEntities(String(html[start.upperBound..<end.lowerBound]))
        if let suffix = title.range(of: "サークルプロフィール") {
            title = String(title[..<suffix.lowerBound])
        }
        title = title.trimmingCharacters(in: .whitespaces)
        if title.hasSuffix("）"), let reading = title.range(of: "（", options: .backwards) {
            title = String(title[..<reading.lowerBound])
        }
        title = title.trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }

    static func feedTitle(for target: DLsiteFeedTarget) async -> String? {
        switch target.source {
        case .circle(let makerID):
            if let name = await fetchCircleName(makerID, shop: target.shop) {
                return name
            }
            let works = try? await fetchListedWorks(for: target, includesAdultContent: true)
            return works?.lazy.compactMap(\.circleName).first
        case .series(let titleID):
            guard let works = try? await fetchListedWorks(for: target, includesAdultContent: true),
                  let first = works.first,
                  let info = try? await fetchWorkInfo([first.productID], shop: target.shop, includesAdultContent: true)
            else { return nil }
            return info[first.productID]?.titleName ?? titleID
        case .creator(let name):
            return name
        }
    }
}
