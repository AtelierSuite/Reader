import Foundation
import Hanami

struct QuickAccessBarItem: Identifiable, Hashable {
    let title: String
    let source: ClassicHomeSource
    let symbolName: String
    let listIconName: String?

    var id: String { source.token }

    /// Follows the start page's Quick Access order, so both layouts share one arrangement.
    @MainActor
    static func items(feedSections: [FeedSection], in feedManager: FeedManager) -> [QuickAccessBarItem] {
        let lists = feedManager.lists
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let quickAccessItems: [TodayQuickAccessItem] = feedSections.map { .feedSection($0) }
            + [.allContent]
            + lists.map { .list($0.id) }
        return TodayQuickAccessPreferences.shared.ordered(quickAccessItems).compactMap { item in
            guard let source = ClassicHomeSource(item) else { return nil }
            var listIconName: String?
            if case .list(let listID) = source {
                listIconName = lists.first { $0.id == listID }?.icon
            }
            return QuickAccessBarItem(
                title: item.browserTitle(in: feedManager),
                source: source,
                symbolName: item.browserSymbolName(in: feedManager),
                listIconName: listIconName
            )
        }
    }
}
