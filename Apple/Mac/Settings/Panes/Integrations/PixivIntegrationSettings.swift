import Hanami
import SwiftUI

struct PixivIntegrationSettings: View {

    @Environment(FeedManager.self) private var feedManager
    @State private var isSignedIn = false
    @State private var isAddingFollowingFeed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            SettingsNote(text: IntegrationText.string("PixivFeeds.Footer"))
        }
        .animation(.smooth.speed(2.0), value: isSignedIn)
    }

    private func addFollowingFeed() {
        isAddingFollowingFeed = true
        Task {
            try? await feedManager.addPixivFollowingFeed()
            isAddingFollowingFeed = false
        }
    }
}
