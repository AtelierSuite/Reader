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

extension AppDisplayMode {

    var switchTitle: String {
        switch self {
        case .browser: String(localized: "DisplayMode.Switch.Browser.Title", table: "Settings")
        case .classic: String(localized: "DisplayMode.Switch.Classic.Title", table: "Settings")
        }
    }

    var switchMessage: String {
        switch self {
        case .browser: String(localized: "DisplayMode.Switch.Browser.Message", table: "Settings")
        case .classic: String(localized: "DisplayMode.Switch.Classic.Message", table: "Settings")
        }
    }
}
