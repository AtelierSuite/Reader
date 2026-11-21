import Foundation

public nonisolated struct AppStoreVersion: Sendable {
    public let version: String
    public let releaseNotes: String?
    public let releaseDate: Date?
}

nonisolated private let appStoreServerDataRegex = try? NSRegularExpression(
    pattern: #"<script type="application/json" id="serialized-server-data">(.*?)</script>"#,
    options: .dotMatchesLineSeparators
)

nonisolated private let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5 Safari/605.1.15"

nonisolated extension AppStoreProvider {

    /// The App Store page embeds the 25 most recent versions; the lookup API only has the current one.
    static func fetchVersionHistory(
        appID: String, storefront: String, isMacApp: Bool
    ) async -> [AppStoreVersion] {
        let platform = isMacApp ? "?platform=mac" : ""
        guard let url = URL(string: "https://apps.apple.com/\(storefront)/app/id\(appID)\(platform)"),
              let (data, _) = try? await URLSession.shared.data(for: desktopRequest(url: url)),
              let html = String(data: data, encoding: .utf8) else { return [] }
        return parseVersionHistory(html)
    }

    // The iPhone user agent is redirected to the itms-appss scheme instead of the web page.
    private static func desktopRequest(url: URL) -> URLRequest {
        var request = URLRequest.sakura(url: url)
        request.setValue(desktopUserAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    static func parseVersionHistory(_ html: String) -> [AppStoreVersion] {
        guard let regex = appStoreServerDataRegex,
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html),
              let root = try? JSONSerialization.jsonObject(with: Data(html[range].utf8)) as? [String: Any],
              let pages = root["data"] as? [[String: Any]],
              let page = pages.first?["data"] as? [String: Any],
              let shelfMapping = page["shelfMapping"] as? [String: Any],
              let mostRecentVersion = shelfMapping["mostRecentVersion"] as? [String: Any],
              let seeAllAction = mostRecentVersion["seeAllAction"] as? [String: Any],
              let pageData = seeAllAction["pageData"] as? [String: Any],
              let shelves = pageData["shelves"] as? [[String: Any]],
              let items = shelves.first?["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let version = item["primarySubtitle"] as? String, !version.isEmpty else { return nil }
            return AppStoreVersion(
                version: version,
                releaseNotes: item["text"] as? String,
                releaseDate: (item["secondarySubtitle"] as? String).flatMap(parseJavaScriptDate)
            )
        }
    }

    private static func parseJavaScriptDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT'Z"
        let dateText = text.components(separatedBy: " (").first ?? text
        return formatter.date(from: dateText)
    }
}
