import Foundation

nonisolated struct PixivMangaSeriesPage: Decodable, Sendable {

    nonisolated struct Thumbnails: Decodable, Sendable {
        let illust: [PixivIllustThumbnail]?
    }

    nonisolated struct Series: Decodable, Sendable {
        let id: String?
        let title: String?
    }

    nonisolated struct Page: Decodable, Sendable {
        let series: [Entry]?
    }

    nonisolated struct Entry: Decodable, Sendable {
        let workId: String?
    }

    let thumbnails: Thumbnails?
    let illustSeries: [Series]?
    let users: [PixivUser]?
    let page: Page?
}

nonisolated struct PixivMangaSeries: Sendable {
    let title: String?
    let avatarURL: String?
    let artworks: [PixivArtwork]

    init(seriesID: String, page: PixivMangaSeriesPage) {
        title = page.illustSeries?.first { $0.id == seriesID }?.title
        avatarURL = page.users?.first?.avatarURL
        let thumbnails = page.thumbnails?.illust ?? []
        artworks = (page.page?.series ?? []).compactMap { entry in
            thumbnails.first { $0.id == entry.workId }.flatMap(PixivArtwork.init(thumbnail:))
        }
    }
}

nonisolated struct PixivNovelSeries: Decodable, Sendable {
    let title: String?
    let profileImageUrl: String?
}

nonisolated struct PixivNovelSeriesContents: Decodable, Sendable {

    nonisolated struct Thumbnails: Decodable, Sendable {
        let novel: [PixivNovelThumbnail]?
    }

    let thumbnails: Thumbnails?
}
