import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

private nonisolated final class IconAssetBundle {}

public extension Iconography {
    func defaultIcon(for feed: Feed) async -> PlatformImage? {
        if MastodonProvider.isFeedURL(feed.url) {
            return fediverseIcon()
        }
        if feed.isFediverseFeed {
            return await profileIcon(siteURL: feed.siteURL) ?? fediverseIcon()
        }
        if feed.isSubstackFeed, let appID = AppStoreFeedIcons.appID(for: feed) {
            if let image = await profileIcon(siteURL: feed.siteURL) { return image }
            return await appStoreIcon(appID: appID)
        }
        return await icon(for: feed.domain, siteURL: feed.siteURL)
    }

    /// Drops the cached profile photo and service icon so the next lookup refetches both.
    func refreshDefaultIcon(for feed: Feed) async -> PlatformImage? {
        forgetProfileIcon(siteURL: feed.siteURL)
        if let appID = AppStoreFeedIcons.appID(for: feed) {
            invalidateAppStoreIcon(appID: appID)
        }
        return await defaultIcon(for: feed)
    }

    func icon(for section: FeedSection) async -> PlatformImage? {
        let domain: String
        switch section {
        case .bluesky: domain = "bsky.app"
        case .instagram: domain = "instagram.com"
        case .note: domain = "note.com"
        case .reddit: domain = "reddit.com"
        case .substack: domain = "substack.com"
        case .x: domain = "x.com"
        case .youtube: domain = "youtube.com"
        case .dlsite: domain = "dlsite.com"
        case .dmm: domain = "dmm.co.jp"
        case .github: domain = "github.com"
        case .hackerNews: domain = "news.ycombinator.com"
        case .netflix: domain = "netflix.com"
        case .pixiv: domain = "pixiv.net"
        case .qiita: domain = "qiita.com"
        case .telegram: domain = "telegram.org"
        case .tumblr: domain = "tumblr.com"
        case .zenn: domain = "zenn.dev"
        case .appStore: domain = "apps.apple.com"
        case .fediverse: return fediverseIcon()
        case .feeds, .podcasts, .vimeo, .niconico: return nil
        }
        return await icon(for: domain)
    }

    private func fediverseIcon() -> PlatformImage? {
        let bundle = Bundle(for: IconAssetBundle.self)
        #if canImport(UIKit)
        return UIImage(named: "FediverseIcon", in: bundle, compatibleWith: nil)
        #else
        return bundle.image(forResource: "FediverseIcon")
        #endif
    }
}
