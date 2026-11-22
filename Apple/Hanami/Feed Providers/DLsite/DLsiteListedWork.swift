import Foundation
import SwiftSoup

nonisolated struct DLsiteListedWork: Sendable {
    let productID: String
    let title: String?
    let circleName: String?
    let creatorNames: [String]
    let coverURL: String?
    let sampleImageURLs: [String]
}

nonisolated struct DLsiteSearchResponse: Decodable {
    let searchResult: String

    enum CodingKeys: String, CodingKey {
        case searchResult = "search_result"
    }
}

nonisolated extension DLsiteListedWork {

    private static let mainImageRegex = try? NSRegularExpression(pattern: #"'(//[^']+_img_main\.jpg)'"#)
    private static let sampleThumbRegex = try? NSRegularExpression(pattern: #"'thumb'\s*:\s*'([^']+)'"#)

    static func parseSearchResult(_ html: String) -> [DLsiteListedWork] {
        guard let document = try? SwiftSoup.parseBodyFragment(html),
              let items = try? document.select("li[data-list_item_product_id]") else { return [] }
        return items.array().compactMap(parseItem)
    }

    private static func parseItem(_ item: Element) -> DLsiteListedWork? {
        guard let productID = try? item.attr("data-list_item_product_id"),
              DLsiteProvider.isProductID(productID) else { return nil }
        let titleLink = try? item.select(".work_name a").first()
        let title = (try? titleLink?.attr("title")).flatMap { $0.isEmpty ? nil : $0 }
            ?? (try? titleLink?.text())
        let circleName = try? item.select(".maker_name > a").first()?.text()
        let creatorNames = (try? item.select(".author a").array().compactMap { try? $0.text() }) ?? []
        let popoverSource = (try? item.select(".work_img_popover img").first()?.attr(":src")) ?? ""
        let samplesValue = (try? item.select("[data-view_samples]").first()?.attr("data-view_samples")) ?? ""
        return DLsiteListedWork(
            productID: productID,
            title: title,
            circleName: circleName.flatMap { $0.isEmpty ? nil : $0 },
            creatorNames: creatorNames.filter { !$0.isEmpty },
            coverURL: DLsiteProvider.absoluteImageURL(firstCapture(of: mainImageRegex, in: popoverSource)),
            sampleImageURLs: captures(of: sampleThumbRegex, in: samplesValue).compactMap { value in
                DLsiteProvider.absoluteImageURL(value.replacingOccurrences(of: "\\/", with: "/"))
            }
        )
    }

    private static func firstCapture(of regex: NSRegularExpression?, in text: String) -> String? {
        captures(of: regex, in: text).first
    }

    private static func captures(of regex: NSRegularExpression?, in text: String) -> [String] {
        guard let regex else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).map { match in
            nsText.substring(with: match.range(at: 1))
        }
    }
}
