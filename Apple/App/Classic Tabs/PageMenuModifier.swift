import EnhancedNavigation
import SwiftUI

private struct PageMenuModifier<Menu: View>: ViewModifier {

    @Environment(\.isClassicTabsActive) private var isClassicTabsActive
    let isEnabled: Bool
    @ViewBuilder let menu: () -> Menu

    func body(content: Content) -> some View {
        if isClassicTabsActive {
            content.toolbar {
                if isEnabled {
                    ToolbarItem(placement: .topBarTrailing) {
                        menu()
                            .labelStyle(.iconOnly)
                    }
                }
            }
        } else {
            content.tabOmniboxAccessory(isEnabled: isEnabled, menu)
        }
    }
}

extension View {
    /// The page's own actions: in the omnibox's menu inside the browser, and
    /// in the top bar inside classic tabs.
    func pageMenu<Menu: View>(
        isEnabled: Bool = true,
        @ViewBuilder _ menu: @escaping () -> Menu
    ) -> some View {
        modifier(PageMenuModifier(isEnabled: isEnabled, menu: menu))
    }
}
