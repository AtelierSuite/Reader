import Foundation

nonisolated struct DLsiteWorkInfo: Decodable, Sendable {
    let siteID: String?
    let makerID: String?
    let ageCategory: Int?
    let titleID: String?
    let titleName: String?
    let workName: String?
    let workImage: String?
    let registDate: String?

    enum CodingKeys: String, CodingKey {
        case siteID = "site_id"
        case makerID = "maker_id"
        case ageCategory = "age_category"
        case titleID = "title_id"
        case titleName = "title_name"
        case workName = "work_name"
        case workImage = "work_image"
        case registDate = "regist_date"
    }

    static let adultAgeCategory = 3

    var isAdult: Bool {
        ageCategory == Self.adultAgeCategory
    }

    var shop: DLsiteShop? {
        siteID.flatMap(DLsiteShop.init(pathSegment:))
    }

    var publishedDate: Date? {
        registDate.flatMap { Self.registDateFormatter.date(from: $0) }
    }

    private static let registDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

nonisolated struct DLsiteWorkInfoEntry: Decodable, Sendable {
    let info: DLsiteWorkInfo?

    init(from decoder: Decoder) throws {
        info = try? DLsiteWorkInfo(from: decoder)
    }
}
