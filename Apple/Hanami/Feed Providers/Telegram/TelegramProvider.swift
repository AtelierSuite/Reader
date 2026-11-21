import Foundation

/// Reads public Telegram channels through their server-rendered web preview.
public final class TelegramProvider: Sendable {

    public nonisolated static let reservedNames: Set<String> = [
        "s", "c", "joinchat", "addstickers", "addemoji", "addtheme", "addlist", "share",
        "proxy", "socks", "iv", "login", "setlanguage", "bg", "contact", "invoice",
        "boost", "giftcode", "confirmphone", "blog", "faq", "apps", "dl"
    ]

    public nonisolated static func previewURL(for channel: String, before postID: Int? = nil) -> URL? {
        let query = postID.map { "?before=\($0)" } ?? ""
        return URL(string: "https://t.me/s/\(channel)\(query)")
    }

    public nonisolated static func isValidChannelName(_ name: String) -> Bool {
        guard !reservedNames.contains(name.lowercased()),
              let first = name.unicodeScalars.first,
              CharacterSet.letters.contains(first), first.isASCII,
              (4...32).contains(name.count) else { return false }
        return name.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "_")
        }
    }

    public func fetchChannel(_ channel: String) async throws -> TelegramChannelFetchResult {
        guard let url = Self.previewURL(for: channel) else { throw TelegramFetchError.unavailable }
        let (data, response) = try await URLSession.shared.data(for: .sakura(url: url))
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              httpResponse.url?.path.hasPrefix("/s/") == true,
              let html = String(data: data, encoding: .utf8),
              let result = Self.parseChannelPage(html, channel: channel) else {
            throw TelegramFetchError.unavailable
        }
        return result
    }
}
