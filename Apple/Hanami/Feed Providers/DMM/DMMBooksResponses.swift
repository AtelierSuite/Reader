import Foundation

nonisolated struct DMMBookSeries: Decodable, Sendable {
    let title: String
    let latestContentId: String?
}

nonisolated struct DMMBookVolumes: Decodable, Sendable {
    let volumeBooks: [DMMBookVolume]
}

nonisolated struct DMMBookVolume: Decodable, Sendable {

    struct ImageURLs: Decodable, Sendable {
        let pl: String?
        let ps: String?
    }

    let contentId: String
    let title: String
    let synopsis: String?
    let volumeNumber: Int?
    let contentPublishDate: String?
    let imageUrls: ImageURLs?

    var publishedDate: Date? {
        contentPublishDate.flatMap { ISO8601DateFormatter().date(from: $0) }
    }
}

