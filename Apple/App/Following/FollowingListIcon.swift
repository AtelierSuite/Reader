import SwiftUI
import Hanami

struct FollowingListIcon: View {

    @Environment(FeedManager.self) var feedManager
    let list: FeedList
    var size: CGFloat = 56

    private var cornerRadius: CGFloat {
        size * 12 / 56
    }

    private var innerPadding: CGFloat {
        size * 8 / 56
    }

    private var gridSpacing: CGFloat {
        size * 4 / 56
    }

    private var listTint: Color? {
        ListIcon(rawValue: list.icon)?.gradientColors.0
    }

    private var miniIconSize: CGFloat {
        let inner = size - (innerPadding * 2)
        return (inner - gridSpacing) / 2
    }

    private var miniIconCornerRadius: CGFloat {
        cornerRadius * miniIconSize / size
    }

    private var feedsInList: [Feed] {
        let ids = feedManager.feedIDs(for: list)
        let ordered = feedManager.feeds.filter { ids.contains($0.id) }
        return Array(ordered.prefix(4))
    }

    var body: some View {
        feedGrid
            .padding(innerPadding)
            .frame(width: size, height: size)
            .drawingGroup()
            .wiggleRotation()
            .wiggleGlassEffect(
                in: RoundedRectangle(cornerRadius: cornerRadius),
                tint: listTint?.opacity(0.3)
            )
    }

    @ViewBuilder
    private var feedGrid: some View {
        let feeds = feedsInList
        VStack(spacing: gridSpacing) {
            HStack(spacing: gridSpacing) {
                gridSlot(feed: feeds.indices.contains(0) ? feeds[0] : nil)
                gridSlot(feed: feeds.indices.contains(1) ? feeds[1] : nil)
            }
            HStack(spacing: gridSpacing) {
                gridSlot(feed: feeds.indices.contains(2) ? feeds[2] : nil)
                gridSlot(feed: feeds.indices.contains(3) ? feeds[3] : nil)
            }
        }
    }

    @ViewBuilder
    private func gridSlot(feed: Feed?) -> some View {
        if let feed {
            FeedIcon(feed: feed, size: miniIconSize, cornerRadius: miniIconCornerRadius)
                .id(feed.id)
        } else {
            Color.clear
                .frame(width: miniIconSize, height: miniIconSize)
        }
    }
}
