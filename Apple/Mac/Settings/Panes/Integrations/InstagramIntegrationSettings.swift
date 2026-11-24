import Hanami
import SwiftUI

struct InstagramIntegrationSettings: View {

    @AppStorage("Instagram.HideReels") private var hideReels = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AccountSessionRow(
                signInTitle: IntegrationText.string("InstagramProfileFeeds.SignIn"),
                signOutTitle: IntegrationText.string("InstagramProfileFeeds.SignOut"),
                checkSession: { InstagramProvider.hasSession() },
                cachedAccount: { InstagramProvider.cachedSignedInAccount },
                fetchAccount: { await InstagramProvider.fetchSignedInAccount() },
                signOut: { await InstagramProvider.clearSession() },
                loginView: { InstagramLoginView() }
            )
            SettingsNote(text: IntegrationText.string("InstagramProfileFeeds.Footer"))
            Toggle(IntegrationText.string("Instagram.HideReels"), isOn: $hideReels)
                .padding(.top, 12)
            SettingsNote(text: IntegrationText.string("Instagram.HideReels.Footer"))
        }
    }
}
