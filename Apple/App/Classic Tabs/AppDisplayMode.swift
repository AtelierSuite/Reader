import Foundation

enum AppDisplayMode: String, CaseIterable, Identifiable {
    case browser
    case classic

    static let storageKey = "App.DisplayMode"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .browser: String(localized: "DisplayMode.Browser", table: "Settings")
        case .classic: String(localized: "DisplayMode.Classic", table: "Settings")
        }
    }
}
