import Foundation

public extension FeedSection {
    var providerSymbolName: String? {
        switch self {
        case .feeds, .podcasts: nil
        case .hackerNews: "provider.hackernews"
        case .appStore: "provider.appstore"
        case .playStore: "provider.playstore"
        default: "provider.\(rawValue)"
        }
    }
}
