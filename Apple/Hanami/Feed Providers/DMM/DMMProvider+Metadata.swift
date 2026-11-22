import Foundation

extension DMMProvider: MetadataProvider {

    public nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        if case .bookSeries = DMMFeedTarget(pageURL: url)?.source { return true }
        return false
    }

    public static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard case .bookSeries(let shop, let seriesID) = DMMFeedTarget(pageURL: url)?.source,
              let series = try? await fetchBookSeries(seriesID, shop: shop) else { return nil }
        let latestVolume = try? await fetchBookVolumes(seriesID, shop: shop, count: 1).first
        return FetchedFeedMetadata(
            displayName: series.title,
            iconURL: (latestVolume?.imageUrls?.ps).flatMap(URL.init(string:)),
            iconNeedsSquareCrop: true
        )
    }
}
