import Foundation

public nonisolated enum FeedSection: String, CaseIterable, Codable, Sendable {
    case feeds
    case podcasts
    case appStore
    case bluesky
    case fediverse
    case instagram
    case note
    case reddit
    case substack
    case vimeo
    case x
    case youtube
    case niconico
    case dlsite
    case dmm
    case github
    case hackerNews
    case netflix
    case pixiv
    case qiita
    case telegram
    case tumblr
    case zenn

    public var localizedTitle: String {
        switch self {
        case .feeds: String(localized: "FeedSection.Feeds", table: "Feeds")
        case .podcasts: String(localized: "FeedSection.Podcasts", table: "Feeds")
        case .appStore: String(localized: "FeedSection.AppStore", table: "Feeds")
        case .bluesky: String(localized: "FeedSection.Bluesky", table: "Feeds")
        case .fediverse: String(localized: "FeedSection.Fediverse", table: "Feeds")
        case .instagram: String(localized: "FeedSection.Instagram", table: "Feeds")
        case .note: String(localized: "FeedSection.Note", table: "Feeds")
        case .reddit: String(localized: "FeedSection.Reddit", table: "Feeds")
        case .substack: String(localized: "FeedSection.Substack", table: "Feeds")
        case .vimeo: String(localized: "FeedSection.Vimeo", table: "Feeds")
        case .x: String(localized: "FeedSection.X", table: "Feeds")
        case .youtube: String(localized: "FeedSection.YouTube", table: "Feeds")
        case .niconico: String(localized: "FeedSection.Niconico", table: "Feeds")
        case .dlsite: String(localized: "FeedSection.DLsite", table: "Feeds")
        case .dmm: String(localized: "FeedSection.DMM", table: "Feeds")
        case .github: String(localized: "FeedSection.GitHub", table: "Feeds")
        case .hackerNews: String(localized: "FeedSection.HackerNews", table: "Feeds")
        case .netflix: String(localized: "FeedSection.Netflix", table: "Feeds")
        case .pixiv: String(localized: "FeedSection.Pixiv", table: "Feeds")
        case .qiita: String(localized: "FeedSection.Qiita", table: "Feeds")
        case .telegram: String(localized: "FeedSection.Telegram", table: "Feeds")
        case .tumblr: String(localized: "FeedSection.Tumblr", table: "Feeds")
        case .zenn: String(localized: "FeedSection.Zenn", table: "Feeds")
        }
    }

    public static var displayOrder: [FeedSection] {
        let pinned: [FeedSection] = [.feeds, .podcasts]
        let others = allCases
            .filter { !pinned.contains($0) }
            .sorted { $0.localizedTitle.localizedStandardCompare($1.localizedTitle) == .orderedAscending }
        return pinned + others
    }
}
