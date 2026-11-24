import SwiftUI
import Hanami

struct XSettingsView: View {

    @State private var isCheckingLogin = true
    @State private var isXSignedIn = false
    @State private var signedInAccount: String?
    @State private var showXLogin = false

    var body: some View {
        List {
            Section {
                if isCheckingLogin {
                    ProgressView()
                } else if isXSignedIn {
                    if let signedInAccount {
                        SignedInAccountRow(account: signedInAccount)
                    }
                    Button(String(localized: "XProfileFeeds.RefreshAuth", table: "Integrations")) {
                        Task {
                            await XProvider.refetchQueryIDs()
                        }
                    }
                    Button(String(localized: "XProfileFeeds.SignOut", table: "Integrations"), role: .destructive) {
                        Task {
                            await XProvider.clearSession()
                            isXSignedIn = false
                            signedInAccount = nil
                        }
                    }
                } else {
                    Button(String(localized: "XProfileFeeds.SignIn", table: "Integrations")) {
                        showXLogin = true
                    }
                }
            } footer: {
                Text(String(localized: "XProfileFeeds.Footer", table: "Integrations"))
            }
        }
        .animation(.smooth.speed(2.0), value: isXSignedIn)
        .navigationTitle(String(localized: "X", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showXLogin) {
            Task {
                await refreshSession()
            }
        } content: {
            XLoginView()
        }
        .task {
            await refreshSession()
        }
    }

    private func refreshSession() async {
        isCheckingLogin = true
        isXSignedIn = XProvider.hasSession()
        isCheckingLogin = false
        if isXSignedIn {
            signedInAccount = XProvider.cachedSignedInAccount
            signedInAccount = await XProvider.fetchSignedInAccount()
        } else {
            signedInAccount = nil
        }
    }
}
