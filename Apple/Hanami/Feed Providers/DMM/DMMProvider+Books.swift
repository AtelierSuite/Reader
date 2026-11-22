import Foundation

nonisolated extension DMMProvider {

    static func fetchBookSeries(_ seriesID: String, shop: DMMFeedTarget.Shop) async throws -> DMMBookSeries {
        try await fetchBooksJSON(
            DMMBookSeries.self, path: "/ajax/bff/series/", shop: shop,
            queryItems: [URLQueryItem(name: "series_id", value: seriesID)]
        )
    }

    static func fetchBookVolumes(
        _ seriesID: String, shop: DMMFeedTarget.Shop, count: Int
    ) async throws -> [DMMBookVolume] {
        try await fetchBooksJSON(
            DMMBookVolumes.self, path: "/ajax/bff/contents_book/", shop: shop,
            queryItems: [
                URLQueryItem(name: "series_id", value: seriesID),
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "per_page", value: String(count)),
                URLQueryItem(name: "last_read_position", value: "0"),
                URLQueryItem(name: "order", value: "desc"),
                URLQueryItem(name: "purchase_status", value: "all"),
                URLQueryItem(name: "format_webp", value: "1")
            ]
        ).volumeBooks
    }

    private static func fetchBooksJSON<Body: Decodable & Sendable>(
        _ type: Body.Type, path: String, shop: DMMFeedTarget.Shop, queryItems: [URLQueryItem]
    ) async throws -> Body {
        var components = URLComponents()
        components.scheme = "https"
        components.host = shop.booksHost
        components.path = path
        components.queryItems = [URLQueryItem(name: "shop_name", value: shop.rawValue)] + queryItems
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetchData(from: url, sendsAgeCookie: false)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Body.self, from: data)
    }

    static func bookVolumeURL(seriesID: String, contentID: String, shop: DMMFeedTarget.Shop) -> String {
        "https://\(shop.booksHost)/product/\(seriesID)/\(contentID)/"
    }

    static func articleItem(
        for volume: DMMBookVolume, seriesID: String, shop: DMMFeedTarget.Shop, author: String? = nil
    ) -> ArticleInsertItem {
        let coverURL = volume.imageUrls?.pl ?? volume.imageUrls?.ps
        let synopsisHTML = volume.synopsis?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let coverHTML = coverURL.map { "<figure><img src=\"\(RSSParser.escapeXMLAttribute($0))\"></figure>" } ?? ""
        let synopsisParagraph = synopsisHTML.isEmpty ? "" : "<p>\(synopsisHTML)</p>"
        return ArticleInsertItem(
            title: volume.title,
            url: bookVolumeURL(seriesID: seriesID, contentID: volume.contentId, shop: shop),
            data: ArticleInsertData(
                author: author,
                summary: plainText(fromHTML: synopsisHTML),
                content: coverHTML + synopsisParagraph,
                imageURL: coverURL,
                publishedDate: volume.publishedDate
            )
        )
    }

    static func plainText(fromHTML html: String) -> String? {
        let withBreaks = html.replacingOccurrences(
            of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive]
        )
        let text = RSSParser.decodeHTMLEntities(RSSParser.stripHTMLTags(withBreaks))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
