import SwiftUI
import UIKit
import Hanami

enum HomeSection: String, CaseIterable, Identifiable {
    case today
    case all
    case feeds
    case podcasts
    case appStore
    case playStore
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

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .today: String(localized: "HomeSection.Today", table: "Home")
        case .all: String(localized: "Shared.AllArticles")
        case .feeds: String(localized: "FeedSection.Feeds", table: "Feeds")
        case .podcasts: String(localized: "FeedSection.Podcasts", table: "Feeds")
        case .appStore: String(localized: "FeedSection.AppStore", table: "Feeds")
        case .playStore: String(localized: "FeedSection.PlayStore", table: "Feeds")
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

    var systemImage: String? {
        switch self {
        case .today: "sun.max"
        case .all: "square.stack"
        case .feeds: "newspaper"
        case .podcasts: "headphones"
        default: nil
        }
    }

    /// Brand-tinted accent used for the Today top tab bar's selected indicator.
    var tabAccentStyle: AnyShapeStyle {
        switch self {
        case .today: AnyShapeStyle(Color.accentColor)
        case .podcasts: AnyShapeStyle(Color.indigo)
        case .bluesky: AnyShapeStyle(Color.blue)
        case .fediverse: AnyShapeStyle(LinearGradient(
            colors: [.red, .yellow, .green, .blue, .indigo],
            startPoint: .leading,
            endPoint: .trailing
        ))
        case .instagram: AnyShapeStyle(Color.brown)
        case .note: AnyShapeStyle(Color.gray)
        case .reddit, .substack: AnyShapeStyle(Color.orange)
        case .x: AnyShapeStyle(Color(uiColor: .label))
        case .youtube: AnyShapeStyle(Color.red)
        default: AnyShapeStyle(Color.accentColor)
        }
    }

    /// Foreground color for the selected tab's text in the Today tab bar.
    /// Sections with colored capsules use white; X uses `Color.primary` for
    /// the capsule (black/white per appearance) so its text must invert.
    var tabSelectedTextColor: Color {
        switch self {
        case .fediverse, .x: Color(uiColor: .systemBackground)
        default: .white
        }
    }

    var feedSection: FeedSection? {
        switch self {
        case .today, .all: nil
        case .feeds: .feeds
        case .podcasts: .podcasts
        case .appStore: .appStore
        case .playStore: .playStore
        case .bluesky: .bluesky
        case .fediverse: .fediverse
        case .instagram: .instagram
        case .note: .note
        case .reddit: .reddit
        case .substack: .substack
        case .vimeo: .vimeo
        case .x: .x
        case .youtube: .youtube
        case .niconico: .niconico
        case .dlsite: .dlsite
        case .dmm: .dmm
        case .github: .github
        case .hackerNews: .hackerNews
        case .netflix: .netflix
        case .pixiv: .pixiv
        case .qiita: .qiita
        case .telegram: .telegram
        case .tumblr: .tumblr
        case .zenn: .zenn
        }
    }
}
