import SwiftUI
import Hanami

struct YouTubeSettingsView: View {

    @AppStorage("YouTube.SponsorBlock.Enabled") private var sponsorBlockEnabled = false
    @AppStorage("YouTube.SponsorBlock.Categories") private var sponsorBlockCategories = "sponsor,selfpromo,interaction"

    @State private var isYouTubeSignedIn = false
    @State private var showYouTubeLogin = false
    @State private var isCheckingSession = true

    var body: some View {
        List {
            Section {
                if isCheckingSession {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if isYouTubeSignedIn {
                    Button(String(localized: "YouTubePlayer.SignOut", table: "Integrations")) {
                        Task {
                            await YouTubePlayerView.clearYouTubeSession()
                            isYouTubeSignedIn = false
                        }
                    }
                } else {
                    Button(String(localized: "YouTubePlayer.SignIn", table: "Integrations")) {
                        showYouTubeLogin = true
                    }
                }
            } footer: {
                Text(String(localized: "YouTubePlayer.Footer", table: "Integrations"))
            }

            Section {
                Toggle(
                    String(localized: "YouTube.SponsorBlock", table: "Settings"),
                    isOn: $sponsorBlockEnabled
                )
            } footer: {
                Text(String(localized: "YouTube.SponsorBlock.Footer", table: "Settings"))
            }

            if sponsorBlockEnabled {
                Section {
                    ForEach(SponsorBlockCategory.allCases, id: \.rawValue) { category in
                        Toggle(category.displayName, isOn: Binding(
                            get: {
                                sponsorBlockCategories
                                    .split(separator: ",")
                                    .map(String.init)
                                    .contains(category.rawValue)
                            },
                            set: { enabled in
                                var cats = sponsorBlockCategories
                                    .split(separator: ",")
                                    .map(String.init)
                                    .filter { !$0.isEmpty }
                                if enabled {
                                    if !cats.contains(category.rawValue) {
                                        cats.append(category.rawValue)
                                    }
                                } else {
                                    cats.removeAll { $0 == category.rawValue }
                                }
                                sponsorBlockCategories = cats.joined(separator: ",")
                            }
                        ))
                    }
                } header: {
                    Text(String(localized: "YouTube.SponsorBlock.Categories", table: "Settings"))
                }
            }
        }
        .animation(.smooth.speed(2.0), value: sponsorBlockEnabled)
        .navigationTitle(String(localized: "YouTube", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showYouTubeLogin) {
            Task {
                isYouTubeSignedIn = await YouTubePlayerView.hasYouTubeSession()
            }
        } content: {
            YouTubeLoginView()
        }
        .task {
            await YouTubePlayerView.warmUpWebView()
            isYouTubeSignedIn = await YouTubePlayerView.hasYouTubeSession()
            isCheckingSession = false
        }
    }
}
