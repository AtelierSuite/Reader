import Foundation

public extension SubstackAuth {

    nonisolated static func fetchSignedInAccount() async -> String? {
        guard let cookieValue = cookieHeader(for: "substack.com"),
              let profileURL = URL(string: "https://substack.com/api/v1/user/profile/self") else {
            return nil
        }

        var request = URLRequest(url: profileURL, timeoutInterval: 15)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieValue, forHTTPHeaderField: "Cookie")
        request.httpShouldHandleCookies = false

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let decoded = try? JSONDecoder().decode(SubstackSelfProfileResponse.self, from: data) else {
            return cachedSignedInAccount
        }

        let handle = decoded.handle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = decoded.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = decoded.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let displayAccount: String?
        if !handle.isEmpty {
            displayAccount = "@\(handle)"
        } else if !email.isEmpty {
            displayAccount = email
        } else if !name.isEmpty {
            displayAccount = name
        } else {
            displayAccount = nil
        }

        if let displayAccount {
            setCachedSignedInAccount(displayAccount)
            return displayAccount
        }
        return cachedSignedInAccount
    }
}

private nonisolated struct SubstackSelfProfileResponse: Decodable, Sendable {
    let handle: String?
    let email: String?
    let name: String?
}
