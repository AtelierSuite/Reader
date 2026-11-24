import Foundation

public extension XProvider {

    nonisolated static func signedInUserID() -> String? {
        guard let twid = cookieStore.load()?.first(where: { $0.name == "twid" })?.value else {
            return nil
        }
        let decoded = twid.removingPercentEncoding ?? twid
        guard decoded.hasPrefix("u=") else { return nil }
        let userID = String(decoded.dropFirst(2))
        guard !userID.isEmpty, userID.allSatisfy(\.isNumber) else { return nil }
        return userID
    }

    @MainActor
    static func fetchSignedInAccount() async -> String? {
        guard let cookies = readXCookiesFromKeychain(),
              let userID = signedInUserID() else {
            return cachedSignedInAccount
        }
        await fetchQueryIDsIfNeeded()
        if userByRestIdQueryID == nil, await refetchQueryIDsIfRestoredFromStorage() {
            log("XProvider", "Refetched query IDs for UserByRestId")
        }
        guard let queryID = userByRestIdQueryID,
              let url = buildGraphQLURL(
                queryID: queryID,
                operationName: "UserByRestId",
                variables: ["userId": userID, "withSafetyModeUserFields": true],
                features: userByScreenNameFeatures
              ) else {
            return cachedSignedInAccount
        }
        let request = XProvider().buildRequest(url: url, cookies: cookies)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let screenName = parseScreenName(from: data) else {
            return cachedSignedInAccount
        }
        let account = "@\(screenName)"
        setCachedSignedInAccount(account)
        return account
    }

    private nonisolated static func parseScreenName(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObject = json["data"] as? [String: Any],
              let user = dataObject["user"] as? [String: Any],
              let result = user["result"] as? [String: Any] else {
            return nil
        }
        let core = result["core"] as? [String: Any]
        let legacy = result["legacy"] as? [String: Any]
        let screenName = (core?["screen_name"] as? String) ?? (legacy?["screen_name"] as? String)
        let trimmed = screenName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
