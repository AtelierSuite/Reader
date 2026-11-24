import SwiftUI
import Hanami

struct SubstackSettingsView: View {

    @State private var isCheckingLogin = true
    @State private var isSignedIn = false
    @State private var signedInAccount: String?
    @State private var showLogin = false

    var body: some View {
        List {
            Section {
                if isCheckingLogin {
                    ProgressView()
                } else if isSignedIn {
                    if let signedInAccount {
                        SignedInAccountRow(account: signedInAccount)
                    }
                    Button(String(localized: "Substack.SignOut", table: "Integrations"), role: .destructive) {
                        Task {
                            await SubstackAuth.clearSession()
                            isSignedIn = false
                            signedInAccount = nil
                        }
                    }
                } else {
                    Button(String(localized: "Substack.SignIn", table: "Integrations")) {
                        showLogin = true
                    }
                }
            } footer: {
                Text(String(localized: "Substack.Footer", table: "Integrations"))
            }
        }
        .navigationTitle(String(localized: "Substack", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogin) {
            Task {
                await refreshSession()
            }
        } content: {
            SubstackLoginView()
        }
        .task {
            await refreshSession()
        }
    }

    private func refreshSession() async {
        isCheckingLogin = true
        isSignedIn = SubstackAuth.hasSession()
        isCheckingLogin = false
        if isSignedIn {
            signedInAccount = SubstackAuth.cachedSignedInAccount
            signedInAccount = await SubstackAuth.fetchSignedInAccount()
        } else {
            signedInAccount = nil
        }
    }
}
