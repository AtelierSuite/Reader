import Foundation
import Hanami

/// Stacking two `.sheet(isPresented:)` modifiers on one view silently drops all
/// but the last, so the shell presents every sheet through a single item.
enum BrowserSheetKind: Identifiable {
    case addFeed(url: String)
    case discoveryLogin(BrowserDiscoveryLogin)
    case generateWebFeed(url: String)

    var id: String {
        switch self {
        case .addFeed(let url): "addFeed:\(url)"
        case .discoveryLogin(let login): "discoveryLogin:\(login.feed.url)"
        case .generateWebFeed(let url): "generateWebFeed:\(url)"
        }
    }
}
