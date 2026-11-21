import Foundation

nonisolated struct PixivIllustDetail: Decodable, Sendable {

    nonisolated struct ImageURLs: Decodable, Sendable {
        let regular: String?
    }

    let userId: String?
    let userName: String?
    let description: String?
    let urls: ImageURLs?
}

nonisolated struct PixivNovelDetail: Decodable, Sendable {

    nonisolated struct EmbeddedImage: Decodable, Sendable {
        let urls: [String: String]?
    }

    let userId: String?
    let userName: String?
    let content: String?
    let coverUrl: String?
    let textEmbeddedImages: PixivKeyedCollection<EmbeddedImage>?

    var uploadedImageURLs: [String: String] {
        (textEmbeddedImages?.values ?? [:]).compactMapValues { image in
            image.urls?["1200x1200"] ?? image.urls?["original"]
        }
    }
}

nonisolated struct PixivInsertedIllust: Decodable, Sendable {

    nonisolated struct Illust: Decodable, Sendable {
        let images: [String: String?]?
    }

    let visible: Bool?
    let illust: Illust?

    var imageURL: String? {
        guard visible != false, let images = illust?.images else { return nil }
        return (images["medium"] ?? nil) ?? (images["original"] ?? nil)
    }
}

nonisolated struct PixivTagSearch: Decodable, Sendable {

    nonisolated struct Results: Decodable, Sendable {
        let data: [PixivIllustThumbnail]?
    }

    let illustManga: Results?
}

nonisolated struct PixivFollowLatest: Decodable, Sendable {

    nonisolated struct Thumbnails: Decodable, Sendable {
        let illust: [PixivIllustThumbnail]?
    }

    let thumbnails: Thumbnails?
}

nonisolated struct PixivRanking: Decodable, Sendable {
    let contents: [PixivRankingEntry]?
}

nonisolated struct PixivRankingEntry: Decodable, Sendable {
    let illustID: Int?
    let title: String?
    let url: String?
    let userName: String?
    let pageCount: Int?
    let uploadTimestamp: TimeInterval?

    private enum CodingKeys: String, CodingKey {
        case illustID = "illust_id"
        case title, url
        case userName = "user_name"
        case pageCount = "illust_page_count"
        case uploadTimestamp = "illust_upload_timestamp"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        illustID = try? container.decode(Int.self, forKey: .illustID)
        title = try? container.decode(String.self, forKey: .title)
        url = try? container.decode(String.self, forKey: .url)
        userName = try? container.decode(String.self, forKey: .userName)
        pageCount = (try? container.decode(Int.self, forKey: .pageCount))
            ?? (try? container.decode(String.self, forKey: .pageCount)).flatMap { Int($0) }
        uploadTimestamp = try? container.decode(TimeInterval.self, forKey: .uploadTimestamp)
    }
}
