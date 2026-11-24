import SwiftUI
import Hanami

struct PixivSettingsView: View {

    @Environment(FeedManager.self) private var feedManager

    @State private var isCheckingLogin = true
    @State private var isPixivSignedIn = false
    @State private var signedInAccount: String?
    @State private var showPixivLogin = false
    @State private var isAddingFollowingFeed = false

    var body: some View {
        List {
            Section {
                if isCheckingLogin {
                    ProgressView()
                } else if isPixivSignedIn {
                    if let signedInAccount {
                        SignedInAccountRow(account: signedInAccount)
                    }
                    Button(String(localized: "PixivFeeds.SignOut", table: "Integrations"), role: .destructive) {
                        Task {
                            await PixivProvider.clearSession()
                            isPixivSignedIn = false
                            signedInAccount = nil
                        }
                    }
                } else {
                    Button(String(localized: "PixivFeeds.SignIn", table: "Integrations")) {
                        showPixivLogin = true
                    }
                }
            } footer: {
                Text(String(localized: "PixivFeeds.Footer", table: "Integrations"))
            }

            if isPixivSignedIn {
                Section {
                    Button(String(localized: "Pixiv.AddFollowingFeed", table: "Integrations")) {
                        addFollowingFeed()
                    }
                    .disabled(isAddingFollowingFeed || feedManager.hasPixivFollowingFeed)
                }
            }
        }
        .animation(.smooth.speed(2.0), value: isPixivSignedIn)
        .navigationTitle(String(localized: "Pixiv", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPixivLogin) {
            Task {
                await refreshSession()
            }
        } content: {
            PixivLoginView()
        }
        .task {
            await refreshSession()
        }
    }

    private func refreshSession() async {
        isCheckingLogin = true
        isPixivSignedIn = PixivProvider.hasSession()
        isCheckingLogin = false
        if isPixivSignedIn {
            signedInAccount = PixivProvider.cachedSignedInAccount
            signedInAccount = await PixivProvider.fetchSignedInAccount()
        } else {
            signedInAccount = nil
        }
    }

    private func addFollowingFeed() {
        isAddingFollowingFeed = true
        Task {
            try? await feedManager.addPixivFollowingFeed()
            isAddingFollowingFeed = false
        }
    }
}
