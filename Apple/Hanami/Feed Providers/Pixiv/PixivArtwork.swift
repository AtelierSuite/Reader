import Foundation

nonisolated struct PixivArtwork: Sendable {
    let id: String
    let title: String
    let authorName: String?
    let imageURL: String?
    let pageCount: Int
    let publishedDate: Date?
    let restriction: Int

    var pageURL: String { "\(PixivProvider.origin)/artworks/\(id)" }

    init?(thumbnail: PixivIllustThumbnail) {
        guard let id = thumbnail.id, !id.isEmpty, let title = thumbnail.title else { return nil }
        self.id = id
        self.title = title
        authorName = thumbnail.userName
        imageURL = thumbnail.url
        pageCount = max(thumbnail.pageCount ?? 1, 1)
        publishedDate = thumbnail.createDate.flatMap(PixivDate.parse)
        restriction = thumbnail.xRestrict ?? 0
    }

    init?(rankingEntry entry: PixivRankingEntry) {
        guard let illustID = entry.illustID, let title = entry.title else { return nil }
        id = String(illustID)
        self.title = title
        authorName = entry.userName
        imageURL = entry.url
        pageCount = max(entry.pageCount ?? 1, 1)
        publishedDate = entry.uploadTimestamp.map { Date(timeIntervalSince1970: $0) }
        restriction = 0
    }
}

nonisolated struct PixivNovel: Sendable {
    let id: String
    let title: String
    let authorName: String?
    let coverURL: String?
    let captionHTML: String?
    let publishedDate: Date?
    let restriction: Int

    var pageURL: String { "\(PixivProvider.origin)/novel/show.php?id=\(id)" }

    init?(thumbnail: PixivNovelThumbnail) {
        guard let id = thumbnail.id, !id.isEmpty, let title = thumbnail.title else { return nil }
        self.id = id
        self.title = title
        authorName = thumbnail.userName
        coverURL = thumbnail.url
        captionHTML = thumbnail.description
        publishedDate = thumbnail.createDate.flatMap(PixivDate.parse)
        restriction = thumbnail.xRestrict ?? 0
    }
}

nonisolated enum PixivDate {

    static func parse(_ string: String) -> Date? {
        try? Date(string, strategy: .iso8601)
    }
}
