import SwiftUI

enum ClassicTabs {
    static let storageKey = "App.UsesClassicTabs"

    @MainActor static var isAvailable: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}

extension EnvironmentValues {
    /// True inside the iPhone tab bar layout, where pages keep the system
    /// navigation bar instead of the browser's omnibox.
    @Entry var isClassicTabsActive: Bool = false
}
