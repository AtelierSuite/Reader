import SwiftUI
import Hanami

struct PixivSettingsView: View {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Labs.PixivFeeds") private var pixivFeedsEnabled: Bool = false

    @State private var isCheckingLogin = true
    @State private var isPixivSignedIn = false
    @State private var showPixivLogin = false
    @State private var isAddingFollowingFeed = false

    var body: some View {
        List {
            Section {
                Toggle(String(localized: "PixivFeeds", table: "Integrations"), isOn: $pixivFeedsEnabled)

                if pixivFeedsEnabled {
                    if isCheckingLogin {
                        ProgressView()
                    } else if isPixivSignedIn {
                        Button(String(localized: "PixivFeeds.SignOut", table: "Integrations")) {
                            Task {
                                await PixivProvider.clearSession()
                                isPixivSignedIn = false
                            }
                        }
                    } else {
                        Button(String(localized: "PixivFeeds.SignIn", table: "Integrations")) {
                            showPixivLogin = true
                        }
                    }
                }
            } footer: {
                Text(String(localized: "PixivFeeds.Footer", table: "Integrations"))
            }

            if pixivFeedsEnabled && isPixivSignedIn {
                Section {
                    Button(String(localized: "Pixiv.AddFollowingFeed", table: "Integrations")) {
                        addFollowingFeed()
                    }
                    .disabled(isAddingFollowingFeed || feedManager.hasPixivFollowingFeed)
                }
            }
        }
        .animation(.smooth.speed(2.0), value: pixivFeedsEnabled)
        .animation(.smooth.speed(2.0), value: isPixivSignedIn)
        .navigationTitle(String(localized: "Pixiv", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPixivLogin) {
            Task {
                isCheckingLogin = true
                isPixivSignedIn = PixivProvider.hasSession()
                isCheckingLogin = false
            }
        } content: {
            PixivLoginView()
        }
        .task {
            isPixivSignedIn = PixivProvider.hasSession()
            isCheckingLogin = false
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
