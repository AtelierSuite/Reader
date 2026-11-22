import Foundation

public nonisolated struct ParsedArticle: Sendable {
    public var title: String
    public var url: String
    public var author: String?
    public var summary: String?
    public var content: String?
    public var imageURL: String?
    public var carouselImageURLs: [String] = []
    public var publishedDate: Date?
    public var audioURL: String?
    public var duration: Int?
    /// Site-specific elements such as `hatena:imageurl`, keyed by element name, for feed dialects to read.
    public var sourceFields: [String: String] = [:]
    /// The entry's description as the feed sent it, before it is cleaned into `summary`.
    public var descriptionHTML: String?
}
