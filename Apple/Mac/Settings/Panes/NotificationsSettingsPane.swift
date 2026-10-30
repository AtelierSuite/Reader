import Hanami
import SwiftUI

struct NotificationsSettingsPane: View {

    let feedManager: FeedManager

    @AppStorage(NewContentNotifications.enabledKey) private var notificationsEnabled = true
    @AppStorage(NewContentNotifications.checkIntervalKey)
    private var checkInterval: NewContentCheckInterval = .oneHour
    @State private var isPermissionDenied = false

    private var sortedFeeds: [Feed] {
        feedManager.feeds.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    var body: some View {
        SettingsForm {
            Group {
                LabeledContent(SettingsText.settings("Section.Notifications")) {
                    Toggle(SettingsText.settings("Notifications.Enabled"), isOn: $notificationsEnabled)
                }
                SettingsPicker(SettingsText.settings("Notifications.CheckInterval"), selection: $checkInterval) {
                    Text(SettingsText.settings("Refresh.30min"))
                        .tag(NewContentCheckInterval.thirtyMinutes)
                    Text(SettingsText.settings("Refresh.1hour"))
                        .tag(NewContentCheckInterval.oneHour)
                }
                .disabled(!notificationsEnabled)
                LabeledContent {
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsNote(text: SettingsText.settings("Notifications.Footer.Mac"))
                        if isPermissionDenied {
                            permissionDeniedNote
                        }
                    }
                } label: {
                    Text(verbatim: "")
                }
            }
            SettingsGroupSpacer()
            LabeledContent(SettingsText.settings("Notifications.Feeds")) {
                VStack(alignment: .leading, spacing: 8) {
                    List(sortedFeeds) { feed in
                        NotificationFeedToggle(feedManager: feedManager, feed: feed)
                    }
                    .listStyle(.bordered)
                    .frame(width: 360, height: 240)
                    SettingsNote(text: SettingsText.settings("Notifications.Feeds.Footer"))
                }
                .disabled(!notificationsEnabled)
            }
        }
        .task {
            await refreshPermissionStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshPermissionStatus() }
        }
        .onChange(of: notificationsEnabled) { _, isEnabled in
            NewContentNotifications.postDidChange()
            guard isEnabled else { return }
            Task {
                _ = await NewContentNotifications.requestAuthorization()
                await refreshPermissionStatus()
            }
        }
        .onChange(of: checkInterval) {
            NewContentNotifications.postDidChange()
        }
    }

    private var permissionDeniedNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(SettingsText.settings("Notifications.PermissionDenied"), systemImage: "bell.slash.fill")
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360, alignment: .leading)
            Button(SettingsText.settings("Notifications.OpenSettings")) {
                if let settingsURL = NotificationPermissionAlert.settingsURL {
                    NSWorkspace.shared.open(settingsURL)
                }
            }
        }
    }

    private func refreshPermissionStatus() async {
        isPermissionDenied = await NewContentNotifications.isAlertPermissionDenied()
    }
}

private struct NotificationFeedToggle: View {

    let feedManager: FeedManager
    let feed: Feed

    var body: some View {
        Toggle(isOn: Binding {
            feed.notifiesNewContent
        } set: { isOn in
            feedManager.setNotifiesNewContent(isOn, for: feed)
            if isOn {
                Task { _ = await NewContentNotifications.requestAuthorization() }
            }
        }) {
            HStack(spacing: 8) {
                FeedIcon(feed: feed, size: 18)
                Text(feed.title)
                    .lineLimit(1)
            }
        }
    }
}
