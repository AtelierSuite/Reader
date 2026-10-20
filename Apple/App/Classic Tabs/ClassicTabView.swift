import SwiftUI
import Hanami

/// The iPhone tab bar layout, offered as an alternative to the browser. Each
/// tab hosts the same pages the browser parks its tabs on.
struct ClassicTabView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("YouTube.OpenMode") var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @AppStorage("App.ClassicTabs.SelectedTab") var selectedTab: ClassicTab = .following
    @State var paths: [ClassicTab: NavigationPath] = [:]
    @State private var addFeedURL = ""
    @State private var isPresentingAddFeed = false
    @State private var addFeedSession = AddFeedSession()
    @Namespace private var followingZoom

    @Binding var pendingFeedURL: String?
    @Binding var pendingArticleID: Int64?
    @Binding var pendingOpenRequest: OpenArticleRequest?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Tabs.Feeds", systemImage: "dot.radiowaves.up.forward", value: ClassicTab.following) {
                ClassicTabStack(path: path(for: .following)) {
                    FollowingPage(followingNavigationNamespace: followingZoom)
                }
            }
            Tab("Tabs.Bookmarks", systemImage: "bookmark", value: ClassicTab.bookmarks) {
                ClassicTabStack(path: path(for: .bookmarks)) {
                    BookmarksContentView()
                }
            }
            Tab("Tabs.Discover", systemImage: "magnifyingglass", value: ClassicTab.discover) {
                ClassicTabStack(path: path(for: .discover)) {
                    ClassicDiscoverPage()
                }
            }
            Tab("Tabs.Profile", systemImage: "person.crop.circle", value: ClassicTab.profile) {
                ProfileView(showsCloseButton: false)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(\.isClassicTabsActive, true)
        .sheet(isPresented: $isPresentingAddFeed) {
            AddFeedView(initialURL: addFeedURL, session: addFeedSession)
                .environment(feedManager)
        }
        .onChange(of: pendingFeedURL) {
            if let url = pendingFeedURL {
                addFeedURL = url
                isPresentingAddFeed = true
                pendingFeedURL = nil
            }
        }
        .onChange(of: pendingArticleID) {
            handlePendingArticleIfNeeded()
        }
        .onChange(of: pendingOpenRequest) {
            handlePendingOpenRequestIfNeeded()
        }
        .task {
            handlePendingArticleIfNeeded()
            handlePendingOpenRequestIfNeeded()
        }
    }

    func path(for tab: ClassicTab) -> Binding<NavigationPath> {
        Binding {
            paths[tab] ?? NavigationPath()
        } set: { newPath in
            paths[tab] = newPath
        }
    }
}
