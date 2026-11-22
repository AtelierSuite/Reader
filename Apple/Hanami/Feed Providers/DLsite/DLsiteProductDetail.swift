import Foundation

nonisolated struct DLsiteProductDetail: Decodable, Sendable {

    nonisolated struct Named: Decodable, Sendable {
        let name: String
    }

    nonisolated struct SampleImage: Decodable, Sendable {
        let url: String
    }

    let shortIntroduction: String?
    let workTypeName: String?
    let price: Int?
    let pageCount: Int?
    let genres: [String]
    let creatorsByRole: [String: [String]]
    let sampleImageURLs: [String]

    enum CodingKeys: String, CodingKey {
        case shortIntroduction = "intro_s"
        case workTypeName = "work_type_string"
        case price
        case pageCount = "page_number"
        case genres
        case creators = "creaters"
        case sampleImages = "image_samples"
    }

    // DLsite encodes empty objects as `[]`, so every collection decodes leniently.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shortIntroduction = try? container.decodeIfPresent(String.self, forKey: .shortIntroduction)
        workTypeName = try? container.decodeIfPresent(String.self, forKey: .workTypeName)
        price = try? container.decodeIfPresent(Int.self, forKey: .price)
        pageCount = try? container.decodeIfPresent(Int.self, forKey: .pageCount)
        genres = ((try? container.decodeIfPresent([Named].self, forKey: .genres)) ?? []).map(\.name)
        creatorsByRole = ((try? container.decodeIfPresent([String: [Named]].self, forKey: .creators)) ?? [:])
            .mapValues { $0.map(\.name) }
        sampleImageURLs = ((try? container.decodeIfPresent([SampleImage].self, forKey: .sampleImages)) ?? [])
            .compactMap { DLsiteProvider.absoluteImageURL($0.url) }
    }
}
