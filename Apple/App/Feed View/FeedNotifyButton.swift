import SwiftUI
import Hanami

struct FeedNotifyButton: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) private var openURL
    let feed: Feed
    let size: CGFloat
    let namespace: Namespace.ID

    @State private var isShowingPermissionAlert = false

    var body: some View {
        Button {
            toggleNotifications()
        } label: {
            Image(systemName: "bell")
                .environment(\.symbolVariants, feed.notifiesNewContent ? .fill : .none)
                .font(.subheadline.weight(.semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
        }
        .compatibleGlassButtonStyle()
        .buttonBorderShape(.circle)
        .accessibilityLabel(String(
            localized: feed.notifiesNewContent ? "FeedHeader.Notify.Off" : "FeedHeader.Notify.On",
            table: "Feeds"
        ))
        .compatibleGlassEffectID("Notify", in: namespace)
        .alert(
            String(localized: "FeedHeader.Notify.Denied.Title", table: "Feeds"),
            isPresented: $isShowingPermissionAlert
        ) {
            Button(String(localized: "FeedHeader.Notify.Denied.OpenSettings", table: "Feeds")) {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text(String(localized: "FeedHeader.Notify.Denied.Message", table: "Feeds"))
        }
    }

    private func toggleNotifications() {
        guard !feed.notifiesNewContent else {
            withAnimation(.smooth.speed(2.0)) {
                feedManager.setNotifiesNewContent(false, for: feed)
            }
            return
        }
        Task {
            if await NewContentNotifications.requestAuthorization() {
                withAnimation(.smooth.speed(2.0)) {
                    feedManager.setNotifiesNewContent(true, for: feed)
                }
            } else {
                isShowingPermissionAlert = true
            }
        }
    }
}
