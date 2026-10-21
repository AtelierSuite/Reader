import EnhancedNavigation
import SwiftUI
import Hanami

struct BrowserTabSwitcher: View {

    @Environment(BrowserTabStore.self) private var store
    @Environment(FeedManager.self) private var feedManager
    @State private var isShowingSettings = false

    var body: some View {
        TabSwitcher(
            store: store,
            strings: .browser,
            placeholderIcon: .asset("SakuraIcon"),
            rebuildingPath: { [feedManager] token, path in
                token.append(to: &path, in: feedManager)
            },
            cardLabel: { tab in
                BrowserLocationLabel(
                    description: BrowserLocationDescription.describe(
                        tab, feedManager: feedManager, prefersContentTitle: true
                    ),
                    iconSize: 16,
                    titleFont: .caption.weight(.medium),
                    showsSubtitle: false
                )
            },
            topTrailingItem: { settingsButton }
        )
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(titleDisplayMode: .inline)
                .environment(feedManager)
        }
    }

    private var settingsButton: some View {
        Button {
            isShowingSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel(String(localized: "Tabs.Settings"))
    }
}

private extension TabSwitcherStrings {
    static var browser: TabSwitcherStrings {
        TabSwitcherStrings(
            title: { count in String(localized: "Tabs.Count \(count)", table: "Browser") },
            closeAll: String(localized: "Tabs.CloseAll", table: "Browser"),
            newTab: String(localized: "Menu.NewTab", table: "Browser"),
            closeTab: String(localized: "Menu.CloseTab", table: "Browser")
        )
    }
}
