import Hanami
import SwiftUI

struct BlueskySettingsView: View {

    @Environment(FeedManager.self) private var feedManager

    @State private var isCheckingLogin = true
    @State private var signedInHandle: String?
    @State private var showLogin = false
    @State private var showSavedFeedsSheet = false
    @State private var isAddingFollowingFeed = false

    private var isSignedIn: Bool {
        signedInHandle != nil
    }

    var body: some View {
        List {
            Section {
                if isCheckingLogin {
                    ProgressView()
                } else if let handle = signedInHandle {
                    LabeledContent(
                        String(localized: "Bluesky.SignedInAs", table: "Integrations"),
                        value: "@\(handle)"
                    )
                    Button(String(localized: "Bluesky.SignOut", table: "Integrations")) {
                        Task {
                            await BlueskyProvider.clearSession()
                            signedInHandle = nil
                        }
                    }
                } else {
                    Button(String(localized: "Bluesky.SignIn", table: "Integrations")) {
                        showLogin = true
                    }
                }
            } footer: {
                Text(String(localized: "Bluesky.Footer", table: "Integrations"))
            }

            if isSignedIn {
                Section {
                    Button(String(localized: "Bluesky.AddFollowingFeed", table: "Integrations")) {
                        addFollowingFeed()
                    }
                    .disabled(isAddingFollowingFeed || feedManager.hasBlueskyFollowingFeed)

                    Button(String(localized: "Bluesky.ImportSavedFeeds", table: "Integrations")) {
                        showSavedFeedsSheet = true
                    }
                }
            }
        }
        .animation(.smooth.speed(2.0), value: isSignedIn)
        .navigationTitle(String(localized: "Bluesky", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogin) {
            refreshSessionState()
        } content: {
            BlueskyLoginView()
        }
        .sheet(isPresented: $showSavedFeedsSheet) {
            BlueskySavedFeedsSheet()
        }
        .task {
            refreshSessionState()
        }
    }

    private func refreshSessionState() {
        signedInHandle = BlueskyProvider.signedInHandle
        isCheckingLogin = false
    }

    private func addFollowingFeed() {
        isAddingFollowingFeed = true
        Task {
            try? await feedManager.addBlueskyFollowingFeed()
            isAddingFollowingFeed = false
        }
    }
}
