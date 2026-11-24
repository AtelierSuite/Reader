import Foundation

public extension PixivProvider {

    nonisolated static func signedInUserID() -> String? {
        guard let cookies = sessionCookies(),
              let sessionCookie = cookies.first(where: { $0.name == "PHPSESSID" }) else {
            return nil
        }
        guard let separatorIndex = sessionCookie.value.firstIndex(of: "_") else {
            return nil
        }
        let userID = String(sessionCookie.value[..<separatorIndex])
        guard !userID.isEmpty, userID.allSatisfy(\.isNumber) else {
            return nil
        }
        return userID
    }

    nonisolated static func fetchSignedInAccount() async -> String? {
        guard let userID = signedInUserID() else { return nil }
        if let user = try? await fetchUser(userID) {
            let trimmedName = user.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let displayAccount = trimmedName.isEmpty ? userID : trimmedName
            setCachedSignedInAccount(displayAccount)
            return displayAccount
        }
        return cachedSignedInAccount ?? userID
    }
}
