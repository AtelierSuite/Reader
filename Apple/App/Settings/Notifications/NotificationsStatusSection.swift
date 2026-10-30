import SwiftUI

struct NotificationsStatusSection: View {

    @Environment(\.openURL) private var openURL
    let isPermissionDenied: Bool
    let isBackgroundRefreshAvailable: Bool

    var body: some View {
        if isPermissionDenied || !isBackgroundRefreshAvailable {
            Section {
                if isPermissionDenied {
                    warning(
                        String(localized: "Notifications.PermissionDenied", table: "Settings"),
                        systemImage: "bell.slash.fill",
                        settingsURLString: UIApplication.openNotificationSettingsURLString
                    )
                }
                if !isBackgroundRefreshAvailable {
                    warning(
                        String(localized: "Notifications.BackgroundRefreshOff", table: "Settings"),
                        systemImage: "exclamationmark.triangle.fill",
                        settingsURLString: UIApplication.openSettingsURLString
                    )
                }
            }
        }
    }

    private func warning(_ message: String, systemImage: String, settingsURLString: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(message)
                    .font(.subheadline)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.orange)
            }
            Button(String(localized: "Notifications.OpenSettings", table: "Settings")) {
                if let url = URL(string: settingsURLString) {
                    openURL(url)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
    }
}
