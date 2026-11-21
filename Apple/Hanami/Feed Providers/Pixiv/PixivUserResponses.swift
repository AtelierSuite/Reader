import Foundation

nonisolated struct PixivUser: Decodable, Sendable {
    let userId: String?
    let name: String?
    let imageBig: String?
    let image: String?

    var avatarURL: String? { imageBig ?? image }
}

nonisolated struct PixivProfileAll: Decodable, Sendable {
    let illusts: PixivIDList?
    let manga: PixivIDList?
    let novels: PixivIDList?

    var newestIllustMangaIDs: [String] {
        PixivIDList.newestFirst((illusts?.ids ?? []) + (manga?.ids ?? []))
    }

    var newestNovelIDs: [String] {
        PixivIDList.newestFirst(novels?.ids ?? [])
    }
}

nonisolated struct PixivProfileWorks<Work: Decodable & Sendable>: Decodable, Sendable {
    let works: PixivKeyedCollection<Work>
}

nonisolated struct PixivIllustThumbnail: Decodable, Sendable {
    let id: String?
    let title: String?
    let xRestrict: Int?
    let url: String?
    let description: String?
    let userName: String?
    let pageCount: Int?
    let createDate: String?
}

nonisolated struct PixivNovelThumbnail: Decodable, Sendable {
    let id: String?
    let title: String?
    let xRestrict: Int?
    let url: String?
    let description: String?
    let userName: String?
    let createDate: String?
}
