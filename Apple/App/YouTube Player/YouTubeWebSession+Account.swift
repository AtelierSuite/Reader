import CryptoKit
import Foundation
import Hanami
import WebKit

extension YouTubeWebSession {

    private static let accountCacheKey = "YouTubePlayerView.signedInAccount"
    private static let youtubeOrigin = "https://www.youtube.com"

    static var cachedSignedInAccount: String? {
        let stored = UserDefaults.standard.string(forKey: accountCacheKey)
        guard let stored, !stored.isEmpty else { return nil }
        return stored
    }

    static func clearCachedSignedInAccount() {
        UserDefaults.standard.removeObject(forKey: accountCacheKey)
    }

    static func fetchSignedInAccount() async -> String? {
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        let matchingCookies = cookies.filter { cookie in
            let domain = cookie.domain.lowercased()
            return domain.contains("youtube.com") || domain.contains("google.com")
        }
        guard let sapisidCookie = matchingCookies.first(where: { $0.name == "SAPISID" })
            ?? matchingCookies.first(where: { $0.name == "__Secure-3PAPISID" }),
              let accountMenuURL = URL(string: "\(youtubeOrigin)/youtubei/v1/account/account_menu") else {
            return cachedSignedInAccount
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let hashInput = "\(timestamp) \(sapisidCookie.value) \(youtubeOrigin)"
        let digest = Insecure.SHA1.hash(data: Data(hashInput.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        var request = URLRequest(url: accountMenuURL, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("SAPISIDHASH \(timestamp)_\(digest)", forHTTPHeaderField: "Authorization")
        request.setValue(youtubeOrigin, forHTTPHeaderField: "Origin")
        request.setValue("\(youtubeOrigin)/", forHTTPHeaderField: "Referer")
        request.setValue(youtubeOrigin, forHTTPHeaderField: "X-Origin")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(
            HTTPCookie.requestHeaderFields(with: matchingCookies)["Cookie"],
            forHTTPHeaderField: "Cookie"
        )
        request.httpShouldHandleCookies = false
        request.httpBody = Data(
            #"{"context":{"client":{"clientName":"WEB","clientVersion":"2.20250101.00.00"}}}"#.utf8
        )

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let account = parseAccountMenuResponse(data) else {
            return cachedSignedInAccount
        }

        UserDefaults.standard.set(account, forKey: accountCacheKey)
        return account
    }

    private static func parseAccountMenuResponse(_ data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let actions = root["actions"] as? [[String: Any]] else {
            return nil
        }

        for action in actions {
            guard let openPopupAction = action["openPopupAction"] as? [String: Any],
                  let popup = openPopupAction["popup"] as? [String: Any],
                  let menuRenderer = popup["multiPageMenuRenderer"] as? [String: Any],
                  let header = menuRenderer["header"] as? [String: Any],
                  let accountHeader = header["activeAccountHeaderRenderer"] as? [String: Any] else {
                continue
            }

            if let handle = extractYouTubeText(accountHeader["channelHandle"]), !handle.isEmpty {
                return handle.hasPrefix("@") ? handle : "@\(handle)"
            }
            if let email = extractYouTubeText(accountHeader["email"]), !email.isEmpty {
                return email
            }
            if let accountName = extractYouTubeText(accountHeader["accountName"]), !accountName.isEmpty {
                return accountName
            }
        }
        return nil
    }

    private static func extractYouTubeText(_ object: Any?) -> String? {
        guard let dictionary = object as? [String: Any] else { return nil }
        if let simpleText = dictionary["simpleText"] as? String {
            let trimmed = simpleText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if let runs = dictionary["runs"] as? [[String: Any]] {
            let combined = runs.compactMap { $0["text"] as? String }.joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !combined.isEmpty { return combined }
        }
        return nil
    }
}
