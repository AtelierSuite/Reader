import Foundation

public nonisolated struct BlueskySavedFeed: Identifiable, Sendable, Equatable {
    public let id: String
    public let kind: BlueskyFeedTarget.Kind
    public let title: String
    public let subtitle: String?
    public let avatarURL: String?
    public let feedURL: String
    public let siteURL: String
    public let isPinned: Bool

    public init(
        id: String,
        kind: BlueskyFeedTarget.Kind,
        title: String,
        subtitle: String?,
        avatarURL: String?,
        feedURL: String,
        siteURL: String,
        isPinned: Bool
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.avatarURL = avatarURL
        self.feedURL = feedURL
        self.siteURL = siteURL
        self.isPinned = isPinned
    }
}
