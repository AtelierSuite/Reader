import Hanami
import SwiftUI

struct BlueskyIntegrationSettings: View {

    @Environment(FeedManager.self) private var feedManager
    @State private var isSignedIn = false
    @State private var signedInHandle: String?
    @State private var isAddingFollowingFeed = false
    @State private var isShowingSavedFeeds = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let handle = signedInHandle {
                Text(String(localized: "Bluesky.SignedInAs", table: "Integrations") + ": @\(handle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            AccountSessionRow(
                signInTitle: IntegrationText.string("Bluesky.SignIn"),
                signOutTitle: IntegrationText.string("Bluesky.SignOut"),
                checkSession: { BlueskyProvider.hasSession() },
                signOut: { await BlueskyProvider.clearSession() },
                onSessionChange: { signedIn in
                    isSignedIn = signedIn
                    signedInHandle = BlueskyProvider.signedInHandle
                },
                loginView: { BlueskyLoginView() }
            )
            if isSignedIn {
                HStack(spacing: 8) {
                    Button(IntegrationText.string("Bluesky.AddFollowingFeed")) {
                        addFollowingFeed()
                    }
                    .disabled(isAddingFollowingFeed || feedManager.hasBlueskyFollowingFeed)

                    Button(IntegrationText.string("Bluesky.ImportSavedFeeds") + "…") {
                        isShowingSavedFeeds = true
                    }
                }
            }
            SettingsNote(text: IntegrationText.string("Bluesky.Footer"))
        }
        .animation(.smooth.speed(2.0), value: isSignedIn)
        .sheet(isPresented: $isShowingSavedFeeds) {
            BlueskySavedFeedsSheet()
                .environment(feedManager)
                .frame(width: 460, height: 500)
        }
    }

    private func addFollowingFeed() {
        isAddingFollowingFeed = true
        Task {
            try? await feedManager.addBlueskyFollowingFeed()
            isAddingFollowingFeed = false
        }
    }
}
