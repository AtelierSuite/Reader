import Foundation

extension AppStoreProvider: MetadataProvider {

    public nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isProfileURL(url)
    }

    public static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let target = AppStoreFeedTarget(pageURL: url),
              let response = try? await AppStoreProvider().lookup(target) else { return nil }
        let artworkURL = target.kind == .app ? response.apps.first?.artworkUrl512 : nil
        return FetchedFeedMetadata(
            displayName: displayName(for: target, in: response),
            iconURL: artworkURL.flatMap(URL.init(string:))
        )
    }
}
