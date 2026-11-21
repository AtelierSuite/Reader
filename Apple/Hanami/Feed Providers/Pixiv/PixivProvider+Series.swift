import Foundation

nonisolated extension PixivProvider {

    static func fetchMangaSeries(_ seriesID: String) async throws -> PixivMangaSeries {
        let page = try await fetchBody(
            PixivMangaSeriesPage.self,
            percentEncodedPath: "/ajax/series/\(seriesID)",
            queryItems: [URLQueryItem(name: "p", value: "1")]
        )
        return PixivMangaSeries(seriesID: seriesID, page: page)
    }

    static func fetchNovelSeries(_ seriesID: String) async throws -> PixivNovelSeries {
        try await fetchBody(PixivNovelSeries.self, percentEncodedPath: "/ajax/novel/series/\(seriesID)")
    }

    static func fetchNovelSeriesContents(_ seriesID: String) async throws -> [PixivNovel] {
        let contents = try await fetchBody(
            PixivNovelSeriesContents.self,
            percentEncodedPath: "/ajax/novel/series_content/\(seriesID)",
            queryItems: [
                URLQueryItem(name: "limit", value: String(novelsPerRefresh)),
                URLQueryItem(name: "last_order", value: "0"),
                URLQueryItem(name: "order_by", value: "desc")
            ]
        )
        return (contents.thumbnails?.novel ?? [])
            .compactMap(PixivNovel.init(thumbnail:))
            .sorted { (Int($0.id) ?? 0) > (Int($1.id) ?? 0) }
    }
}
