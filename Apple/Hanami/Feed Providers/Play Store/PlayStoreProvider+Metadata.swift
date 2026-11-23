import Foundation

extension PlayStoreProvider: MetadataProvider {

    public nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isProfileURL(url)
    }

    public static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let target = PlayStoreFeedTarget(pageURL: url) else { return nil }
        let provider = PlayStoreProvider()
        if target.isDeveloper {
            guard let page = try? await provider.fetchDeveloperPage(for: target) else { return nil }
            return FetchedFeedMetadata(
                displayName: page.developerName,
                iconURL: page.iconURL.flatMap(URL.init(string:))
            )
        } else {
            guard let details = try? await provider.fetchAppDetails(for: target) else { return nil }
            return FetchedFeedMetadata(
                displayName: details.title,
                iconURL: details.iconURL.flatMap(URL.init(string:))
            )
        }
    }
}
