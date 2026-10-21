import Foundation
import Hanami

/// What the Home tab shows, stored as a token so a deleted list falls back to
/// All Content instead of failing to decode.
enum ClassicHomeSource: Hashable {
    case allContent
    case feedSection(FeedSection)
    case list(Int64)

    static let storageKey = "App.ClassicTabs.HomeSource"

    var token: String {
        switch self {
        case .allContent: "allContent"
        case .feedSection(let section): "feedSection:\(section.rawValue)"
        case .list(let listID): "list:\(listID)"
        }
    }

    init(token: String) {
        let parts = token.split(separator: ":", maxSplits: 1).map(String.init)
        switch (parts.first, parts.count == 2 ? parts[1] : nil) {
        case ("feedSection", let value?):
            self = FeedSection(rawValue: value).map(ClassicHomeSource.feedSection) ?? .allContent
        case ("list", let value?):
            self = Int64(value).map(ClassicHomeSource.list) ?? .allContent
        default:
            self = .allContent
        }
    }
}
