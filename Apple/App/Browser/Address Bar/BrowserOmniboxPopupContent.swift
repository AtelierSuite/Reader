import EnhancedNavigation
import SwiftUI
import Hanami

/// The wide omnibox's popup: the Following grid before anything is typed,
/// suggestions from the top down after.
struct BrowserOmniboxPopupContent: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserOmniboxModel.self) private var omnibox

    private var actions: BrowserOmniboxActions {
        BrowserOmniboxActions(store: store, omnibox: omnibox)
    }

    var body: some View {
        Group {
            if omnibox.query.isEmpty {
                BrowserOmniboxFollowingGrid(
                    openFeed: { feed in actions.open(.feed(feed.id)) },
                    openSection: { section in actions.open(.feedSection(section)) },
                    fitsContent: true
                )
            } else {
                BrowserOmniboxSuggestionList(
                    suggestions: BrowserSuggestionResolver(feedManager: feedManager)
                        .suggestions(for: omnibox.query, contentMatches: omnibox.contentMatches),
                    selectedSuggestionID: omnibox.selectedSuggestionID,
                    apply: actions.apply
                )
            }
        }
        .task(id: omnibox.query) { await actions.refreshContentMatches() }
        .task(id: omnibox.query) {
            await BrowserOmniboxDiscovery(omnibox: omnibox, feedManager: feedManager).refresh()
        }
    }
}
