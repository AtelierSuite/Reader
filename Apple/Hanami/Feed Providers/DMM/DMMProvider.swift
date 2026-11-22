import Foundation

/// Follows DMM Books series and authors, and FANZA 同人 circles and series, by reading DMM's pages.
public final class DMMProvider: Sendable {

    public nonisolated static let bookSeriesScheme = "dmm-series"
    public nonisolated static let bookAuthorScheme = "dmm-author"
    public nonisolated static let doujinCircleScheme = "fanza-doujin-circle"
    public nonisolated static let doujinSeriesScheme = "fanza-doujin-series"
    public nonisolated static let schemes = [bookSeriesScheme, bookAuthorScheme, doujinCircleScheme, doujinSeriesScheme]

    nonisolated static let doujinOrigin = "https://www.dmm.co.jp"
    nonisolated static let volumesPerRefresh = 100
    nonisolated static let detailFetchesPerRefresh = 30

    // DMM serves different markup to the iPhone user agent.
    nonisolated static let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5 Safari/605.1.15"

    public nonisolated static func isDoujinHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "www.dmm.co.jp" || host == "dmm.co.jp"
    }

    public nonisolated static func isAdultFeedURL(_ feedURL: String) -> Bool {
        DMMFeedTarget(feedURL: feedURL)?.isAdult ?? false
    }

    nonisolated static func doujinListURL(article: String, identifier: String) -> String {
        "\(doujinOrigin)/dc/doujin/-/list/=/article=\(article)/id=\(identifier)/"
    }

    nonisolated static func doujinDetailURL(contentID: String) -> String {
        "\(doujinOrigin)/dc/doujin/-/detail/=/cid=\(contentID)/"
    }

    nonisolated static func doujinListArticle(in url: URL) -> (article: String, identifier: String)? {
        let segments = url.path.split(separator: "/").map(String.init)
        guard segments.starts(with: ["dc", "doujin", "-", "list"]),
              let article = parameter("article", in: segments),
              let identifier = parameter("id", in: segments),
              DMMFeedTarget.isNumericID(identifier) else { return nil }
        return (article, identifier)
    }

    nonisolated static func doujinContentID(in url: URL) -> String? {
        let segments = url.path.split(separator: "/").map(String.init)
        guard segments.starts(with: ["dc", "doujin", "-", "detail"]),
              let contentID = parameter("cid", in: segments), !contentID.isEmpty else { return nil }
        return contentID
    }

    private nonisolated static func parameter(_ name: String, in segments: [String]) -> String? {
        segments.first { $0.hasPrefix(name + "=") }.map { String($0.dropFirst(name.count + 1)) }
    }

    nonisolated static func fetchData(from url: URL, sendsAgeCookie: Bool) async throws -> Data {
        var request = URLRequest.sakura(url: url, timeoutInterval: 20)
        request.setValue(desktopUserAgent, forHTTPHeaderField: "User-Agent")
        if sendsAgeCookie {
            let cookie = AdultContentGate.cookie(for: .fanza)
            request.setValue("\(cookie.name)=\(cookie.value)", forHTTPHeaderField: "Cookie")
            request.httpShouldHandleCookies = false
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              httpResponse.url?.path.hasPrefix("/age_check") != true else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    nonisolated static func fetchHTML(from urlString: String, sendsAgeCookie: Bool) async throws -> String {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let data = try await fetchData(from: url, sendsAgeCookie: sendsAgeCookie)
        guard let html = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        return html
    }
}
