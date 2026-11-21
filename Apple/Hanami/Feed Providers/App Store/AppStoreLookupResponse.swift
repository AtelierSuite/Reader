import Foundation

public nonisolated struct AppStoreLookupResponse: Decodable, Sendable {

    public let results: [AppStoreLookupEntry]

    public var artistName: String? {
        results.lazy.compactMap(\.artistName).first
    }

    public var apps: [AppStoreLookupEntry] {
        results.filter { $0.trackId != nil && $0.version != nil }
    }
}

public nonisolated struct AppStoreLookupEntry: Decodable, Sendable {
    public let wrapperType: String?
    public let kind: String?
    public let artistName: String?
    public let trackId: Int?
    public let trackName: String?
    public let version: String?
    public let releaseNotes: String?
    public let releaseDate: Date?
    public let currentVersionReleaseDate: Date?
    public let artworkUrl512: String?

    public var isMacApp: Bool { kind == "mac-software" }

    enum CodingKeys: String, CodingKey {
        case wrapperType, kind, artistName, trackId, trackName, version, releaseNotes
        case releaseDate, currentVersionReleaseDate, artworkUrl512
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wrapperType = try container.decodeIfPresent(String.self, forKey: .wrapperType)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        artistName = try container.decodeIfPresent(String.self, forKey: .artistName)
        trackId = try container.decodeIfPresent(Int.self, forKey: .trackId)
        trackName = try container.decodeIfPresent(String.self, forKey: .trackName)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        releaseNotes = try container.decodeIfPresent(String.self, forKey: .releaseNotes)
        artworkUrl512 = try container.decodeIfPresent(String.self, forKey: .artworkUrl512)
        let parser = RSSParser()
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
            .flatMap { parser.parseDate($0) }
        currentVersionReleaseDate = try container
            .decodeIfPresent(String.self, forKey: .currentVersionReleaseDate)
            .flatMap { parser.parseDate($0) }
    }
}
