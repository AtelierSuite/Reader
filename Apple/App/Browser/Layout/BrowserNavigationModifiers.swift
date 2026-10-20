import EnhancedNavigation
import SwiftUI

/// Wires the app's navigation closures into a tab's path. The page's chrome
/// is EnhancedNavigation's bar, so the top bar goes. Classic tabs have no
/// tab store and keep the system bar.
struct BrowserNavigationEnvironment: ViewModifier {

    @Environment(BrowserTabStore.self) private var store: BrowserTabStore?
    @Binding var path: NavigationPath

    func body(content: Content) -> some View {
        let wired = content
            .environment(\.navigateToFeed) { path.append($0) }
            .environment(\.navigateToEphemeralArticle) { path.append($0) }
            .environment(\.navigateToSummaryHeadline) { path.append($0) }
        if let store {
            wired
                .toolbarVisibility(.hidden, for: .navigationBar)
                .interactivePopGesture(for: store)
        } else {
            wired
        }
    }
}

extension View {
    func browserNavigationEnvironment(path: Binding<NavigationPath>) -> some View {
        modifier(BrowserNavigationEnvironment(path: path))
    }
}
