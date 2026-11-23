import Hanami
import SwiftUI

struct BlueskyLoginView: View {

    var body: some View {
        ProviderSignInView(
            configuration: ProviderSignInView.Configuration(
                section: .bluesky,
                fallbackSymbolName: "cloud.fill",
                serviceName: String(localized: "Bluesky", table: "Integrations"),
                prompt: String(localized: "BlueskyLogin.Prompt", table: "Integrations"),
                helpLinkTitle: String(localized: "BlueskyLogin.CreateAppPassword", table: "Integrations"),
                helpLinkURL: URL(string: "https://bsky.app/settings/app-passwords"),
                usernameLabel: String(localized: "BlueskyLogin.UsernameLabel", table: "Integrations"),
                usernamePlaceholder: String(localized: "BlueskyLogin.UsernamePlaceholder", table: "Integrations"),
                passwordLabel: String(localized: "BlueskyLogin.PasswordLabel", table: "Integrations"),
                passwordPlaceholder: String(localized: "BlueskyLogin.PasswordPlaceholder", table: "Integrations"),
                submitTitle: String(localized: "BlueskyLogin.Submit", table: "Integrations"),
                onSubmit: { identifier, appPassword in
                    _ = try await BlueskyProvider.signIn(identifier: identifier, appPassword: appPassword)
                }
            )
        )
    }
}
