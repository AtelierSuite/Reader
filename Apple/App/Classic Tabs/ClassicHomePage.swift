import SwiftUI
import Hanami

struct ClassicHomePage: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.scenePhase) private var scenePhase
    // Kept out of @AppStorage until the scene goes inactive: a defaults write on
    // every tap invalidates the toolbar and resets the Quick Access bar's scroll.
    @State private var selection = ClassicHomeSource(
        token: UserDefaults.standard.string(forKey: ClassicHomeSource.storageKey) ?? ""
    )

    private var feedSections: [FeedSection] {
        let presentSections = Set(feedManager.feeds.map(\.feedSection))
        return FeedSection.allCases.filter { presentSections.contains($0) }
    }

    private var contentSource: HomeContentSource {
        switch selection {
        case .allContent:
            return .section(nil)
        case .feedSection(let section):
            return feedSections.contains(section) ? .section(section) : .section(nil)
        case .list(let listID):
            guard let list = feedManager.lists.first(where: { $0.id == listID }) else {
                return .section(nil)
            }
            return .list(list)
        }
    }

    var body: some View {
        let tabs = QuickAccessBarItem.items(feedSections: feedSections, in: feedManager)
        // HomeSectionView re-identifies its content per source, which re-adds the
        // toolbar items of a navigation root and makes the Quick Access bar's pill grow
        // from the top left. A stable root keeps the items in place.
        ZStack {
            HomeSectionView(source: contentSource)
        }
        .toolbar {
            if tabs.count > 1 {
                ToolbarItem(placement: .principal) {
                    QuickAccessBar(tabs: tabs, selection: $selection)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                UserDefaults.standard.set(selection.token, forKey: ClassicHomeSource.storageKey)
            }
        }
        .onDisappear {
            UserDefaults.standard.set(selection.token, forKey: ClassicHomeSource.storageKey)
        }
    }
}
