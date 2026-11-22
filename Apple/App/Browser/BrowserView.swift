import EnhancedNavigation
import SwiftUI
import Hanami

/// Prototype Safari-style shell: tabs, one omnibox that both searches and
/// subscribes, and a start page. Enabled from Browsing settings.
struct BrowserView: View {

    @Environment(FeedManager.self) var feedManager

    @State var store = BrowserTabStore.restored()
    @State private var slots = BrowserPageSlots()
    @State private var favourites = BrowserFavourites()
    @State private var omnibox = BrowserOmniboxModel()
    @State private var presentedSheet: BrowserSheetKind?
    @State private var pendingAddFeedURL: String?
    @State private var addFeedSession = AddFeedSession()
    private let mediaPresenter = MediaPresenter.shared

    @Binding var pendingFeedURL: String?
    @Binding var pendingArticleID: Int64?
    @Binding var pendingOpenRequest: OpenArticleRequest?

    var body: some View {
        BrowserAdaptiveShell()
        .environment(\.isBrowserModeActive, true)
        .environment(store)
        .environment(slots)
        .environment(favourites)
        .environment(\.browserBookmarksAction) {
            store.push(BrowserBookmarksDestination())
        }
        .environment(omnibox)
        .environment(\.browserOmniboxAction) {
            withAnimation(BrowserOmniboxModel.transition) {
                omnibox.activate(with: store.displayedTab.pageIdentity?.searchQuery ?? "")
            }
        }
        .environment(\.browserOmniboxSubmit) {
            submitOmnibox()
        }
        .sheet(
            item: $presentedSheet,
            onDismiss: { pendingAddFeedURL = nil },
            content: { sheet in
                switch sheet {
                case .addFeed(let url):
                    AddFeedView(initialURL: url, session: addFeedSession)
                        .environment(feedManager)
                case .discoveryLogin(let login):
                    discoveryLoginView(login)
                        .onDisappear {
                            BrowserOmniboxDiscovery(omnibox: omnibox, feedManager: feedManager)
                                .completeLogin(login)
                        }
                case .generateWebFeed(let url):
                    PetalBuilderView(mode: .create(initialURL: url))
                        .environment(feedManager)
                }
            }
        )
        .onChange(of: omnibox.requestedSheet?.id) {
            if let sheet = omnibox.requestedSheet {
                presentedSheet = sheet
                omnibox.requestedSheet = nil
            }
        }
        .onChange(of: pendingAddFeedURL) {
            if let url = pendingAddFeedURL {
                presentedSheet = .addFeed(url: url)
            }
        }
        .onAppear {
            // Players belong in the tab's stack here, not in a sheet over it:
            // a sheet would cover the browser's own chrome.
            mediaPresenter.detachedHandler = { item in
                switch item {
                case .youTube(let article), .podcast(let article):
                    store.push(article)
                }
            }
        }
        .onDisappear {
            mediaPresenter.detachedHandler = nil
        }
        .onChange(of: pendingArticleID) {
            handlePendingArticleIfNeeded()
        }
        .onChange(of: pendingOpenRequest) {
            handlePendingOpenRequestIfNeeded()
        }
        .task {
            store.loadPersistedSnapshots()
            store.onTabsClosed = { [slots] tabIDs in
                slots.discard(tabIDs)
            }
            handlePendingArticleIfNeeded()
            handlePendingOpenRequestIfNeeded()
        }
        .onChange(of: pendingFeedURL) {
            if let url = pendingFeedURL {
                pendingAddFeedURL = url
                pendingFeedURL = nil
            }
        }
    }

    @ViewBuilder
    private func discoveryLoginView(_ login: BrowserDiscoveryLogin) -> some View {
        switch login {
        case .x: XLoginView()
        case .instagram: InstagramLoginView()
        }
    }

    private func submitOmnibox() {
        let trimmed = omnibox.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Site addresses stay in the omnibox, where their feeds are found.
        guard BrowserAddressInput.siteHost(from: trimmed) == nil else { return }
        store.navigate(to: .search(trimmed))
        withAnimation(BrowserOmniboxModel.transition) {
            omnibox.deactivate()
        }
    }

}
