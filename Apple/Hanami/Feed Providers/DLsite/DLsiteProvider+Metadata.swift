import Foundation

extension DLsiteProvider: MetadataProvider {

    public nonisolated static var fallbackIconURL: URL? {
        URL(string: "\(origin)/modpub/images/web/common/apple_touch_icon_152x152.png")
    }

    public nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isProfileURL(url)
    }

    public static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard case .feed(let target) = DLsitePageLink(url: url) else { return nil }
        return FetchedFeedMetadata(displayName: await feedTitle(for: target), iconURL: fallbackIconURL)
    }
}
