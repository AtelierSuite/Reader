import Foundation
import SwiftSoup

nonisolated private let jsonLDRegex = try? NSRegularExpression(
    pattern: #"<script type="application/ld\+json">(.*?)</script>"#,
    options: .dotMatchesLineSeparators
)

nonisolated extension DMMProvider {

    static func parseBookAuthorList(_ html: String, shop: DMMFeedTarget.Shop) -> DMMWorkList? {
        guard let document = try? SwiftSoup.parse(html, "https://\(shop.booksHost)/"),
              let items = try? document.select("li.m-boxListBookProduct2__item[data-content-id]") else { return nil }
        let works = items.array().compactMap { item -> DMMListedWork? in
            guard let contentID = try? item.attr("data-content-id"), !contentID.isEmpty,
                  let link = try? item.select("a[href*=/product/]").first()?.attr("abs:href"),
                  let linkURL = URL(string: link),
                  let seriesID = bookSeriesID(in: linkURL),
                  let title = text(of: ".m-boxListBookProduct2Tmb__ttl", in: item) else { return nil }
            return DMMListedWork(
                contentID: contentID,
                title: title,
                url: bookVolumeURL(seriesID: seriesID, contentID: contentID, shop: shop),
                coverURL: nonEmpty(try? item.select("img.m-bookImage__img").first()?.attr("src")),
                bookSeriesID: seriesID,
                creator: nil
            )
        }
        return DMMWorkList(name: authorName(fromTitle: pageTitle(of: document)), works: works)
    }

    static func parseDoujinList(_ html: String) -> DMMWorkList? {
        guard let document = try? SwiftSoup.parse(html, doujinOrigin + "/"),
              let items = try? document.select("ul.productList > li.productList__item") else { return nil }
        let works = items.array().compactMap { item -> DMMListedWork? in
            guard let link = try? item.select(".tileListTtl__txt a").first(),
                  let href = try? link.attr("abs:href"),
                  let linkURL = URL(string: href),
                  let contentID = doujinContentID(in: linkURL),
                  let title = nonEmpty(try? link.text()) else { return nil }
            return DMMListedWork(
                contentID: contentID,
                title: title,
                url: doujinDetailURL(contentID: contentID),
                coverURL: nonEmpty(try? item.select(".tileListImg img").first()?.attr("src")),
                bookSeriesID: nil,
                creator: text(of: ".tileListTtl__txt--author a", in: item)
            )
        }
        return DMMWorkList(name: bracketedName(fromTitle: pageTitle(of: document)), works: works)
    }

    static func parseDoujinDetail(_ html: String) -> DMMDoujinDetail? {
        guard let document = try? SwiftSoup.parse(html, doujinOrigin + "/") else { return nil }
        let circleLink = try? document.select("a.circleName__txt[href*=article=maker/id=]").first()
        let seriesLink = informationValue("シリーズ", in: document).flatMap { try? $0.select("a").first() }
        return DMMDoujinDetail(
            publishedDate: informationValue("配信開始日", in: document)
                .flatMap { try? $0.text() }
                .flatMap(parseJSTDate),
            imageURLs: productImageURLs(in: html),
            circle: circleLink.flatMap(linkedList),
            series: seriesLink.flatMap(linkedList)
        )
    }

    private static func informationValue(_ label: String, in document: Document) -> Element? {
        let lists = (try? document.select("dl.informationList").array()) ?? []
        for list in lists where (try? list.select("dt").first()?.text())?
            .trimmingCharacters(in: .whitespaces) == label {
            return try? list.select("dd").first()
        }
        return nil
    }

    private static func linkedList(_ link: Element) -> DMMLinkedList? {
        guard let href = try? link.attr("abs:href"), let url = URL(string: href),
              let (_, identifier) = doujinListArticle(in: url),
              let name = nonEmpty(try? link.text()) else { return nil }
        return DMMLinkedList(identifier: identifier, name: name)
    }

    private static func productImageURLs(in html: String) -> [String] {
        guard let jsonLDRegex else { return [] }
        for match in jsonLDRegex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range(at: 1), in: html),
                  let object = try? JSONSerialization.jsonObject(with: Data(html[range].utf8)) as? [String: Any],
                  object["@type"] as? String == "Product",
                  let images = object["image"] as? [String] else { continue }
            var seen = Set<String>()
            return images.filter { seen.insert($0).inserted }
        }
        return []
    }

    private static func parseJSTDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.date(from: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func bookSeriesID(in url: URL) -> String? {
        let segments = url.path.split(separator: "/").map(String.init)
        guard segments.count >= 2, segments[0] == "product", DMMFeedTarget.isNumericID(segments[1]) else {
            return nil
        }
        return segments[1]
    }

    private static func pageTitle(of document: Document) -> String? {
        nonEmpty(try? document.title())
    }

    /// `荒川弘(あらかわひろむ)の作品一覧 - …` → `荒川弘`
    private static func authorName(fromTitle title: String?) -> String? {
        guard let title, let range = title.range(of: "の作品一覧") else { return nil }
        var name = String(title[..<range.lowerBound])
        if name.hasSuffix(")"), let readingStart = name.lastIndex(of: "(") {
            name = String(name[..<readingStart])
        }
        return nonEmpty(name)
    }

    /// `『パラレル』の作品【…】｜…` → `パラレル`
    private static func bracketedName(fromTitle title: String?) -> String? {
        guard let title, let start = title.firstIndex(of: "『"),
              let end = title[start...].firstIndex(of: "』") else { return nil }
        return nonEmpty(String(title[title.index(after: start)..<end]))
    }

    private static func text(of selector: String, in element: Element) -> String? {
        nonEmpty(try? element.select(selector).first()?.text())
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
