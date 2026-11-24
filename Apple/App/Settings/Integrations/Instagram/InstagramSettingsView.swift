import SwiftUI
import Hanami

struct InstagramSettingsView: View {

    @AppStorage("Instagram.HideReels") private var hideReels: Bool = false

    @State private var isCheckingLogin = true
    @State private var isInstagramSignedIn = false
    @State private var signedInAccount: String?
    @State private var showInstagramLogin = false

    var body: some View {
        List {
            Section {
                if isCheckingLogin {
                    ProgressView()
                } else if isInstagramSignedIn {
                    if let signedInAccount {
                        SignedInAccountRow(account: signedInAccount)
                    }
                    Button(String(localized: "InstagramProfileFeeds.SignOut", table: "Integrations"), role: .destructive) {
                        Task {
                            await InstagramProvider.clearSession()
                            isInstagramSignedIn = false
                            signedInAccount = nil
                        }
                    }
                } else {
                    Button(String(localized: "InstagramProfileFeeds.SignIn", table: "Integrations")) {
                        showInstagramLogin = true
                    }
                }
            } footer: {
                Text(String(localized: "InstagramProfileFeeds.Footer", table: "Integrations"))
            }

            if isInstagramSignedIn {
                Section {
                    Toggle(String(localized: "Instagram.HideReels", table: "Integrations"), isOn: $hideReels)
                } footer: {
                    Text(String(localized: "Instagram.HideReels.Footer", table: "Integrations"))
                }
            }
        }
        .animation(.smooth.speed(2.0), value: isInstagramSignedIn)
        .navigationTitle(String(localized: "Instagram", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showInstagramLogin) {
            Task {
                await refreshSession()
            }
        } content: {
            InstagramLoginView()
        }
        .task {
            await refreshSession()
        }
    }

    private func refreshSession() async {
        isCheckingLogin = true
        isInstagramSignedIn = InstagramProvider.hasSession()
        isCheckingLogin = false
        if isInstagramSignedIn {
            signedInAccount = InstagramProvider.cachedSignedInAccount
            signedInAccount = await InstagramProvider.fetchSignedInAccount()
        } else {
            signedInAccount = nil
        }
    }
}
