import Foundation
import Hanami

nonisolated enum ContentOpenMode: String, CaseIterable, Identifiable, Sendable {
    case inAppViewer
    case browser

    static let storageKey = "Reading.LinkOpenMode"
    var id: String { rawValue }

    static var current: ContentOpenMode {
        UserDefaults.standard.string(forKey: storageKey).flatMap(ContentOpenMode.init(rawValue:)) ?? .inAppViewer
    }

    static func opensInReader(_ urlString: String) -> Bool {
        opensInReader(URL(string: urlString))
    }

    static func opensInReader(_ url: URL?) -> Bool {
        current == .inAppViewer && !ExcludedSites.contains(url)
    }

    /// A feed or folder's own choice wins, except for excluded sites.
    static func resolvedMode(for urlString: String, preferredMode: FeedOpenMode?) -> FeedOpenMode {
        let mode = current
        if mode == .inAppViewer, ExcludedSites.contains(URL(string: urlString)) {
            return .browser
        }
        if let preferredMode, preferredMode != .inAppViewer {
            return preferredMode
        }
        return mode == .browser ? .browser : .inAppViewer
    }
}
