import Foundation

public nonisolated struct ContentAuthor: Sendable, Hashable {
    public let name: String
    public let profileURL: String
}

public nonisolated extension Feed {

    /// Feeds that gather posts from many accounts, so each post carries its own author.
    var hasMultipleAuthors: Bool {
        BlueskyFeedTarget.isFeedURL(url) || MastodonProvider.isFeedURL(url)
    }

    func contentAuthor(of article: Article) -> ContentAuthor? {
        guard hasMultipleAuthors,
              let name = article.author, !name.isEmpty,
              let postURL = URL(string: article.url) else { return nil }
        if BlueskyFeedTarget.isFeedURL(url),
           let handle = BlueskyProvider.profileHandle(from: postURL),
           let profileURL = BlueskyProvider.profileURL(for: handle) {
            return ContentAuthor(name: name, profileURL: profileURL.absoluteString)
        }
        if MastodonProvider.isFeedURL(url),
           let profileURL = MastodonProvider.profileURL(fromStatusURL: postURL) {
            return ContentAuthor(name: name, profileURL: profileURL.absoluteString)
        }
        return nil
    }
}

public extension Iconography {

    func icon(for author: ContentAuthor) async -> PlatformImage? {
        guard let host = URL(string: author.profileURL)?.host else { return nil }
        return await icon(for: host, siteURL: author.profileURL)
    }
}
