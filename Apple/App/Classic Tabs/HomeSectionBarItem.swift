import Foundation
import Hanami

struct HomeSectionBarItem: Identifiable, Hashable {
    let title: String
    let source: ClassicHomeSource
    let listIconName: String?

    var id: String { source.token }

    static func items(feedSections: [FeedSection], lists: [FeedList]) -> [HomeSectionBarItem] {
        [HomeSectionBarItem(
            title: String(localized: "Location.AllContent", table: "Browser"),
            source: .allContent,
            listIconName: nil
        )]
        + feedSections.map {
            HomeSectionBarItem(title: $0.localizedTitle, source: .feedSection($0), listIconName: nil)
        }
        + lists.map {
            HomeSectionBarItem(title: $0.name, source: .list($0.id), listIconName: $0.icon)
        }
    }
}
