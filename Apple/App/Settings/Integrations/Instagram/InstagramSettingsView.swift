import SwiftUI
import Hanami

struct InstagramSettingsView: View {

    @AppStorage("Instagram.HideReels") private var hideReels: Bool = false

    @State private var isCheckingLogin = true
    @State private var isInstagramSignedIn = false
    @State private var showInstagramLogin = false

    var body: some View {
        List {
            Section {
                if isCheckingLogin {
                    ProgressView()
                } else if isInstagramSignedIn {
                    Button(String(localized: "InstagramProfileFeeds.SignOut", table: "Integrations")) {
                        Task {
                            await InstagramProvider.clearSession()
                            isInstagramSignedIn = false
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
                isCheckingLogin = true
                isInstagramSignedIn = InstagramProvider.hasSession()
                isCheckingLogin = false
            }
        } content: {
            InstagramLoginView()
        }
        .task {
            isInstagramSignedIn = InstagramProvider.hasSession()
            isCheckingLogin = false
        }
    }
}
