import Foundation

public nonisolated struct ContentAuthor: Sendable, Hashable {
    public let name: String
    public let profileURL: String
}

public nonisolated extension Feed {

    /// Feeds that gather posts from many accounts, so each post carries its own author.
    var hasMultipleAuthors: Bool {
        BlueskyFeedTarget.isFeedURL(url)
    }

    func contentAuthor(of article: Article) -> ContentAuthor? {
        guard hasMultipleAuthors,
              let name = article.author, !name.isEmpty,
              let postURL = URL(string: article.url),
              let handle = BlueskyProvider.profileHandle(from: postURL),
              let profileURL = BlueskyProvider.profileURL(for: handle) else { return nil }
        return ContentAuthor(name: name, profileURL: profileURL.absoluteString)
    }
}

public extension Iconography {

    func icon(for author: ContentAuthor) async -> PlatformImage? {
        guard let host = URL(string: author.profileURL)?.host else { return nil }
        return await icon(for: host, siteURL: author.profileURL)
    }
}
