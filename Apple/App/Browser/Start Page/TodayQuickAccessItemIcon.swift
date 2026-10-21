import SwiftUI
import Hanami

struct TodayQuickAccessItemIcon: View {

    @Environment(FeedManager.self) private var feedManager
    let item: TodayQuickAccessItem
    var size: CGFloat = 56

    var body: some View {
        switch item {
        case .list(let listID):
            if let list = feedManager.lists.first(where: { $0.id == listID }) {
                FollowingListIcon(list: list, size: size)
            }
        case .feedSection(let section):
            BrowserTodayQuickAccessIcon(
                symbolName: item.browserSymbolName(in: feedManager),
                section: section,
                size: size
            )
        default:
            BrowserTodayQuickAccessIcon(symbolName: item.browserSymbolName(in: feedManager), size: size)
        }
    }
}
