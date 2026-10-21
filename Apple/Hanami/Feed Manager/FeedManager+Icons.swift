import Foundation

/// Sync can deliver feeds across several batches, each of which would otherwise
/// queue the same feeds for another refetch while the first is still running.
@MainActor
private var iconRefreshInFlight: Set<Int64> = []

public extension FeedManager {

    /// Synced feeds arrive carrying metadata only, so every device has to
    /// rebuild the icon files itself. Batched so a large library does not open
    /// one connection per feed at once.
    func refreshIcons(for feedsNeedingIcons: [Feed]) async {
        let pending = feedsNeedingIcons.filter { !iconRefreshInFlight.contains($0.id) }
        guard !pending.isEmpty else { return }
        iconRefreshInFlight.formUnion(pending.map(\.id))
        defer { iconRefreshInFlight.subtract(pending.map(\.id)) }
        var index = 0
        while index < pending.count {
            let end = min(index + Self.iconRefreshBatchSize, pending.count)
            await Iconography.shared.refreshAllIcons(for: Array(pending[index..<end]))
            notifyIconChange()
            index = end
        }
    }

    /// Profile icons for cookie-authenticated services are unreachable while
    /// signed out, so a sign-in refetches the ones that failed.
    func connectProviderSessions() {
        ProviderSessionEvents.onSessionEstablished = { [weak self] service in
            Task { @MainActor [weak self] in
                await self?.refreshIcons(forProvider: service)
            }
        }
    }

    /// The first requests after signing in can fail while the service settles
    /// the new session, so photos that did not load are retried once.
    func refreshIcons(forProvider service: ProviderSessionEvents.Service) async {
        var pending = feeds.filter {
            service.matches($0) && ($0.customIconURL == nil || $0.customIconURL == "photo")
        }
        pending = await refetchProfilePhotos(pending)
        guard !pending.isEmpty else { return }
        try? await Task.sleep(for: .seconds(10))
        _ = await refetchProfilePhotos(pending)
    }

    /// Returns the feeds whose photo could not be fetched.
    private func refetchProfilePhotos(_ pendingFeeds: [Feed]) async -> [Feed] {
        var failedFeeds: [Feed] = []
        var index = 0
        while index < pendingFeeds.count {
            let batch = pendingFeeds[index..<min(index + Self.iconRefreshBatchSize, pendingFeeds.count)]
            let failedIDs = await withTaskGroup(of: Int64?.self) { group in
                for feed in batch {
                    group.addTask {
                        await Iconography.shared.refetchProfilePhoto(for: feed) ? nil : feed.id
                    }
                }
                var failedIDs: Set<Int64> = []
                for await failedID in group {
                    if let failedID { failedIDs.insert(failedID) }
                }
                return failedIDs
            }
            failedFeeds += batch.filter { failedIDs.contains($0.id) }
            notifyIconChange()
            index += batch.count
        }
        return failedFeeds
    }

    internal static var iconRefreshBatchSize: Int { 8 }
}
