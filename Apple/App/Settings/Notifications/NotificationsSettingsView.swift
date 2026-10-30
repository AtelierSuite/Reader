import SwiftUI
import Hanami

struct NotificationsSettingsView: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(NewContentNotifications.enabledKey) private var notificationsEnabled: Bool = true
    @AppStorage(NewContentNotifications.checkIntervalKey)
    private var checkInterval: NewContentCheckInterval = .oneHour
    @State private var isPermissionDenied = false
    @State private var backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus

    private var sortedFeeds: [Feed] {
        feedManager.feeds.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    var body: some View {
        List {
            NotificationsStatusSection(
                isPermissionDenied: isPermissionDenied,
                isBackgroundRefreshAvailable: backgroundRefreshStatus == .available
            )

            Section {
                Toggle(String(localized: "Notifications.Enabled", table: "Settings"),
                       isOn: $notificationsEnabled)
                if notificationsEnabled {
                    Picker(selection: $checkInterval) {
                        Text(String(localized: "Refresh.30min", table: "Settings"))
                            .tag(NewContentCheckInterval.thirtyMinutes)
                        Text(String(localized: "Refresh.1hour", table: "Settings"))
                            .tag(NewContentCheckInterval.oneHour)
                    } label: {
                        Text(String(localized: "Notifications.CheckInterval", table: "Settings"))
                    }
                }
            } footer: {
                Text(String(localized: "Notifications.Footer", table: "Settings"))
            }

            if notificationsEnabled {
                Section {
                    ForEach(sortedFeeds) { feed in
                        NotificationFeedToggleRow(feed: feed)
                    }
                } header: {
                    Text(String(localized: "Notifications.Feeds", table: "Settings"))
                } footer: {
                    Text(String(localized: "Notifications.Feeds.Footer", table: "Settings"))
                }
            }
        }
        .animation(.smooth.speed(2.0), value: notificationsEnabled)
        .settingsListStyle()
        .navigationTitle(String(localized: "Section.Notifications", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
        .task(id: scenePhase) {
            await refreshSystemStatus()
        }
        .onChange(of: notificationsEnabled) { _, isEnabled in
            NewContentNotifications.postDidChange()
            guard isEnabled else { return }
            Task {
                _ = await NewContentNotifications.requestAuthorization()
                await refreshSystemStatus()
            }
        }
        .onChange(of: checkInterval) {
            NewContentNotifications.postDidChange()
        }
    }

    private func refreshSystemStatus() async {
        isPermissionDenied = await NewContentNotifications.isAlertPermissionDenied()
        backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
    }
}
