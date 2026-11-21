import Foundation

extension PixivProvider: MetadataProvider {

    public nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        guard case .user = PixivFeedTarget(pageURL: url)?.source else { return false }
        return true
    }

    public static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard case .user(let userID) = PixivFeedTarget(pageURL: url)?.source,
              let user = try? await fetchUser(userID) else { return nil }
        return FetchedFeedMetadata(
            displayName: user.name,
            iconURL: user.avatarURL.flatMap(URL.init(string:))
        )
    }
}
