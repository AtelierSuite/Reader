import Foundation

public extension XProvider {

    static func fetchSignedInAccount() async -> String? {
        guard let cookies = readXCookiesFromKeychain() else { return nil }
        let provider = XProvider()

        if let account = await fetchAccountFromSettings(provider: provider, cookies: cookies) {
            setCachedSignedInAccount(account)
            return account
        }
        if let account = await fetchAccountFromVerifyCredentials(provider: provider, cookies: cookies) {
            setCachedSignedInAccount(account)
            return account
        }
        return cachedSignedInAccount
    }

    private static func fetchAccountFromSettings(
        provider: XProvider,
        cookies: XCookies
    ) async -> String? {
        guard let settingsURL = URL(string: "https://api.x.com/1.1/account/settings.json") else {
            return nil
        }
        let request = provider.buildRequest(url: settingsURL, cookies: cookies)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let decoded = try? JSONDecoder().decode(XAccountSettingsResponse.self, from: data) else {
            return nil
        }
        let screenName = decoded.screenName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return screenName.isEmpty ? nil : "@\(screenName)"
    }

    private static func fetchAccountFromVerifyCredentials(
        provider: XProvider,
        cookies: XCookies
    ) async -> String? {
        let credentialsEndpoint = "https://api.x.com/1.1/account/verify_credentials.json"
            + "?skip_status=true&include_entities=false"
        guard let credentialsURL = URL(string: credentialsEndpoint) else {
            return nil
        }
        let request = provider.buildRequest(url: credentialsURL, cookies: cookies)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let decoded = try? JSONDecoder().decode(XVerifyCredentialsResponse.self, from: data) else {
            return nil
        }
        let screenName = decoded.screenName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !screenName.isEmpty {
            return "@\(screenName)"
        }
        let displayName = decoded.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return displayName.isEmpty ? nil : displayName
    }
}

private nonisolated struct XAccountSettingsResponse: Decodable, Sendable {
    let screenName: String?

    enum CodingKeys: String, CodingKey {
        case screenName = "screen_name"
    }
}

private nonisolated struct XVerifyCredentialsResponse: Decodable, Sendable {
    let screenName: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case screenName = "screen_name"
        case name
    }
}
