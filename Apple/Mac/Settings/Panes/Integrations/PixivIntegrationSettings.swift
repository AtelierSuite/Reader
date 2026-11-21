import Hanami
import SwiftUI

struct PixivIntegrationSettings: View {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Labs.PixivFeeds") private var pixivFeedsEnabled = false
    @AppStorage(PixivProvider.showsRestrictedWorksKey) private var showsRestrictedWorks = false
    @State private var isSignedIn = false
    @State private var isAddingFollowingFeed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(IntegrationText.string("PixivFeeds"), isOn: $pixivFeedsEnabled)
            SettingsNote(text: IntegrationText.string("PixivFeeds.Footer"))
            if pixivFeedsEnabled {
                AccountSessionRow(
                    signInTitle: IntegrationText.string("PixivFeeds.SignIn"),
                    signOutTitle: IntegrationText.string("PixivFeeds.SignOut"),
                    checkSession: { PixivProvider.hasSession() },
                    signOut: { await PixivProvider.clearSession() },
                    onSessionChange: { isSignedIn = $0 },
                    loginView: { PixivLoginView() }
                )
                if isSignedIn {
                    Button(IntegrationText.string("Pixiv.AddFollowingFeed")) { addFollowingFeed() }
                        .disabled(isAddingFollowingFeed || feedManager.hasPixivFollowingFeed)
                }
                Toggle(IntegrationText.string("Pixiv.ShowRestrictedWorks"), isOn: $showsRestrictedWorks)
                    .padding(.top, 12)
                SettingsNote(text: IntegrationText.string("Pixiv.ShowRestrictedWorks.Footer"))
            }
        }
        .animation(.smooth.speed(2.0), value: pixivFeedsEnabled)
    }

    private func addFollowingFeed() {
        isAddingFollowingFeed = true
        Task {
            try? await feedManager.addPixivFollowingFeed()
            isAddingFollowingFeed = false
        }
    }
}
