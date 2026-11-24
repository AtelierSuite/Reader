import Foundation

public extension InstagramProvider {

    static func fetchSignedInAccount() async -> String? {
        guard let cookies = getInstagramCookies() else { return nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        if let storage = configuration.httpCookieStorage {
            for cookie in cookies.allCookies {
                storage.setCookie(cookie)
            }
        }
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        let provider = InstagramProvider()
        if let account = await fetchAccountFromWebFormData(
            provider: provider,
            cookies: cookies,
            session: session
        ) {
            setCachedSignedInAccount(account)
            return account
        }
        if let account = await fetchAccountFromUserInfo(
            provider: provider,
            cookies: cookies,
            session: session
        ) {
            setCachedSignedInAccount(account)
            return account
        }
        return cachedSignedInAccount
    }

    private static func fetchAccountFromWebFormData(
        provider: InstagramProvider,
        cookies: InstagramCookies,
        session: URLSession
    ) async -> String? {
        guard let formURL = URL(string: "https://www.instagram.com/api/v1/accounts/edit/web_form_data/") else {
            return nil
        }
        let request = provider.buildRequest(
            url: formURL,
            cookies: cookies,
            referer: "https://www.instagram.com/accounts/edit/"
        )
        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let decoded = try? JSONDecoder().decode(InstagramWebFormDataResponse.self, from: data),
              let formData = decoded.formData else {
            return nil
        }
        let username = formData.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !username.isEmpty {
            return "@\(username)"
        }
        let email = formData.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !email.isEmpty {
            return email
        }
        let firstName = formData.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstName.isEmpty ? nil : firstName
    }

    private static func fetchAccountFromUserInfo(
        provider: InstagramProvider,
        cookies: InstagramCookies,
        session: URLSession
    ) async -> String? {
        guard let userID = cookies.allCookies.first(where: { $0.name == "ds_user_id" })?.value,
              !userID.isEmpty,
              let infoURL = URL(string: "https://www.instagram.com/api/v1/users/\(userID)/info/") else {
            return nil
        }
        let request = provider.buildRequest(url: infoURL, cookies: cookies)
        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let decoded = try? JSONDecoder().decode(InstagramUserInfoResponse.self, from: data),
              let user = decoded.user else {
            return nil
        }
        let username = user.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !username.isEmpty {
            return "@\(username)"
        }
        let fullName = user.fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fullName.isEmpty ? nil : fullName
    }
}

private nonisolated struct InstagramWebFormDataResponse: Decodable, Sendable {
    let formData: FormData?

    enum CodingKeys: String, CodingKey {
        case formData = "form_data"
    }

    struct FormData: Decodable, Sendable {
        let username: String?
        let email: String?
        let firstName: String?

        enum CodingKeys: String, CodingKey {
            case username
            case email
            case firstName = "first_name"
        }
    }
}

private nonisolated struct InstagramUserInfoResponse: Decodable, Sendable {
    let user: User?

    struct User: Decodable, Sendable {
        let username: String?
        let fullName: String?

        enum CodingKeys: String, CodingKey {
            case username
            case fullName = "full_name"
        }
    }
}
