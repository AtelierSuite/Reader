import Hanami
import SwiftUI

struct XIntegrationSettings: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AccountSessionRow(
                signInTitle: IntegrationText.string("XProfileFeeds.SignIn"),
                signOutTitle: IntegrationText.string("XProfileFeeds.SignOut"),
                checkSession: { XProvider.hasSession() },
                cachedAccount: { XProvider.cachedSignedInAccount },
                fetchAccount: { await XProvider.fetchSignedInAccount() },
                signOut: { await XProvider.clearSession() },
                loginView: { XLoginView() }
            )
            SettingsNote(text: IntegrationText.string("XProfileFeeds.Footer"))
        }
    }
}
