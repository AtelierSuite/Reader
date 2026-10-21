import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension Iconography {

    /// Profile photo for a service feed, without the site favicon fallback so
    /// callers can fall back to the service icon instead.
    func profileIcon(siteURL: String) async -> PlatformImage? {
        guard let cacheKey = Self.profileCacheKey(siteURL: siteURL) else { return nil }
        if let cached = memoryCache[cacheKey] { return cached }
        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(cacheKey))
        if let data = try? Data(contentsOf: filePath), let image = PlatformImage(data: data) {
            attachDerivedMetrics(cacheKey: cacheKey, to: image)
            memoryCache[cacheKey] = image
            return image
        }
        if isWithinFailureTTL(cacheKey) { return nil }
        if let pending = profileIconRequests[cacheKey] { return await pending.value }

        let request = Task { await self.fetchProfileAvatar(from: siteURL) }
        profileIconRequests[cacheKey] = request
        let image = await request.value
        profileIconRequests[cacheKey] = nil
        guard let image else {
            recordFailedLookup(cacheKey)
            return nil
        }
        forgetFailedLookup(cacheKey)
        try? FileManager.default.removeItem(at: metricsSidecarURL(for: cacheKey))
        return cache(image, cacheKey: cacheKey, filePath: filePath)
    }

    public func hasProfilePhoto(for feed: Feed) -> Bool {
        let cacheKey: String
        switch feed.customIconURL {
        case "photo":
            cacheKey = Self.customIconCacheKey(feedID: feed.id)
        case nil:
            guard let profileKey = Self.profileCacheKey(siteURL: feed.siteURL) else { return false }
            cacheKey = profileKey
        default:
            return true
        }
        if memoryCache[cacheKey] != nil { return true }
        let filePath = cacheDirectory.appendingPathComponent(sanitizedFileName(cacheKey))
        return FileManager.default.fileExists(atPath: filePath.path)
    }

    /// Swaps in the new photo only after it downloads, so a fetch that fails
    /// keeps the photo already shown.
    public func refetchProfilePhoto(for feed: Feed) async -> Bool {
        guard let photo = await fetchProviderPhoto(siteURL: feed.siteURL) else { return false }
        switch feed.customIconURL {
        case "photo":
            replaceCustomIcon(with: photo, feedID: feed.id)
        case nil:
            guard let cacheKey = Self.profileCacheKey(siteURL: feed.siteURL) else { return false }
            forgetProfileIcon(siteURL: feed.siteURL)
            _ = cache(photo, cacheKey: cacheKey,
                      filePath: cacheDirectory.appendingPathComponent(sanitizedFileName(cacheKey)))
        default:
            break
        }
        return true
    }

    nonisolated func fetchProviderPhoto(siteURL: String) async -> PlatformImage? {
        guard let url = URL(string: siteURL),
              let provider = FeedProviderRegistry.metadataFetcher(forSiteURL: url),
              let metadata = await provider.fetchMetadata(for: url),
              let iconURL = metadata.iconURL,
              let image = await downloadImage(from: iconURL) else { return nil }
        return metadata.iconNeedsSquareCrop ? image.centerSquareCropped() : image
    }

    func forgetProfileIcon(siteURL: String) {
        guard let cacheKey = Self.profileCacheKey(siteURL: siteURL) else { return }
        memoryCache[cacheKey] = nil
        forgetFailedLookup(cacheKey)
        try? FileManager.default.removeItem(at: cacheDirectory.appendingPathComponent(sanitizedFileName(cacheKey)))
        try? FileManager.default.removeItem(at: metricsSidecarURL(for: cacheKey))
    }

    /// Matches `cacheKey(domain:siteURL:)` for profile-based domains so existing caches are reused.
    nonisolated static func profileCacheKey(siteURL: String) -> String? {
        guard let url = URL(string: siteURL), let host = url.host else { return nil }
        return url.path.isEmpty ? host : host + url.path
    }

    public nonisolated static func hasServiceFallback(_ feed: Feed) -> Bool {
        feed.isFediverseFeed || AppStoreFeedIcons.appID(for: feed) != nil
    }
}
