import SwiftUI
import Hanami

struct NotificationFeedToggleRow: View {

    @Environment(FeedManager.self) private var feedManager
    let feed: Feed

    private var notifiesNewContent: Binding<Bool> {
        Binding {
            feed.notifiesNewContent
        } set: { isOn in
            feedManager.setNotifiesNewContent(isOn, for: feed)
            if isOn {
                Task { _ = await NewContentNotifications.requestAuthorization() }
            }
        }
    }

    var body: some View {
        Toggle(isOn: notifiesNewContent) {
            HStack(spacing: 12) {
                FeedIcon(feed: feed, size: 28, cornerRadius: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(feed.title)
                        .lineLimit(1)
                    if !feed.domain.isEmpty {
                        Text(feed.domain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}
