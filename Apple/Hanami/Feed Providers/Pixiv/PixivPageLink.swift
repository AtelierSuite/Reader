import Foundation

nonisolated enum PixivPageLink: Sendable {
    case feed(PixivFeedTarget)
    case shortLink(URL)
    case artwork(String)
    case novel(String)

    init?(url: URL) {
        if let target = PixivFeedTarget(pageURL: url) {
            self = .feed(target)
            return
        }
        let host = url.host?.lowercased()
        let segments = PixivFeedTarget.decodedPathSegments(of: url)
        if host == "pixiv.me" {
            guard segments.count == 1 else { return nil }
            self = .shortLink(url)
            return
        }
        guard PixivProvider.isWebHost(host) else { return nil }
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let queryValue = { (name: String) in queryItems.first { $0.name == name }?.value }
        let pathSegments = segments.first.map { $0.count == 2 && $0.allSatisfy(\.isLetter) } == true
            ? Array(segments.dropFirst()) : segments
        if pathSegments.count >= 2, pathSegments[0] == "artworks", pathSegments[1].allSatisfy(\.isNumber) {
            self = .artwork(pathSegments[1])
        } else if pathSegments == ["member_illust.php"], let illustID = queryValue("illust_id") {
            self = .artwork(illustID)
        } else if pathSegments == ["novel", "show.php"], let novelID = queryValue("id") {
            self = .novel(novelID)
        } else {
            return nil
        }
    }
}
