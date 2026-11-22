import Foundation

extension NetflixProvider: MetadataProvider {

    public nonisolated static var fallbackIconURL: URL? {
        URL(string: "https://assets.nflxext.com/ffe/siteui/common/icons/nficon2016.png")
    }

    public nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isProfileURL(url)
    }

    public static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let videoID = videoID(fromPageURL: url),
              let show = try? await fetchShow(videoID: videoID) else { return nil }
        return FetchedFeedMetadata(
            displayName: show.title,
            iconURL: show.artworkURL.flatMap(URL.init(string:)) ?? fallbackIconURL,
            iconNeedsSquareCrop: show.artworkURL != nil
        )
    }
}
