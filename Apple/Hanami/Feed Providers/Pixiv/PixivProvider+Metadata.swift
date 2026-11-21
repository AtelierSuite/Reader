import Foundation

extension PixivProvider: MetadataProvider {

    public nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        switch PixivFeedTarget(pageURL: url)?.source {
        case .user, .mangaSeries, .novelSeries: true
        default: false
        }
    }

    public static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        let displayName: String?
        let avatarURL: String?
        switch PixivFeedTarget(pageURL: url)?.source {
        case .user(let userID):
            guard let user = try? await fetchUser(userID) else { return nil }
            (displayName, avatarURL) = (user.name, user.avatarURL)
        case .mangaSeries(let seriesID, _):
            guard let series = try? await fetchMangaSeries(seriesID) else { return nil }
            (displayName, avatarURL) = (series.title, series.avatarURL)
        case .novelSeries(let seriesID):
            guard let series = try? await fetchNovelSeries(seriesID) else { return nil }
            (displayName, avatarURL) = (series.title, series.profileImageUrl)
        default:
            return nil
        }
        return FetchedFeedMetadata(displayName: displayName, iconURL: avatarURL.flatMap(URL.init(string:)))
    }
}
