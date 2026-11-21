import Foundation

public nonisolated struct TelegramChannelFetchResult: Sendable {
    public let title: String?
    public let avatarURL: String?
    public let posts: [ParsedTelegramPost]
}

public nonisolated struct ParsedTelegramPost: Sendable {
    public let url: String
    public let headline: String?
    public let text: String
    public let imageURLs: [String]
    public let mediaLabel: String?
    public let publishedDate: Date?
}

public nonisolated enum TelegramFetchError: Error {
    /// The channel doesn't exist, isn't public, or has its web preview blocked.
    case unavailable
}
