import Foundation

public nonisolated extension MastodonProvider {

    static func discoveredFeeds(forDomain domain: String) async -> [DiscoveredFeed] {
        guard !domain.isEmpty, let url = URL(string: "https://\(domain)") else { return [] }
        return await discoveredFeeds(forPageURL: url)
    }

    static func discoveredFeeds(forPageURL url: URL) async -> [DiscoveredFeed] {
        guard let host = url.host?.lowercased(), !host.isEmpty else { return [] }
        let path = url.path.lowercased()
        let isLocalPath = path == "/public/local" || path == "/public/local/"
        let isFederatedPath = path == "/public" || path == "/public/"
        let isInstanceLandingPath = path.isEmpty || path == "/"
            || path == "/explore" || path == "/explore/"
            || path == "/home" || path == "/home/"
        guard isLocalPath || isFederatedPath || isInstanceLandingPath else { return [] }

        guard let instance = await fetchInstance(host: host) else { return [] }
        let instanceTitle = instance.displayTitle ?? host

        if isLocalPath {
            let target = MastodonFeedTarget(host: host, scope: .local)
            guard await isTimelineAccessible(target) else { return [] }
            return [DiscoveredFeed(title: instanceTitle, url: target.feedURL, siteURL: target.siteURL)]
        }

        if isFederatedPath {
            let federatedTarget = MastodonFeedTarget(host: host, scope: .federated)
            if await isTimelineAccessible(federatedTarget) {
                return [DiscoveredFeed(title: instanceTitle, url: federatedTarget.feedURL, siteURL: federatedTarget.siteURL)]
            }
            let localTarget = MastodonFeedTarget(host: host, scope: .local)
            if await isTimelineAccessible(localTarget) {
                return [DiscoveredFeed(title: instanceTitle, url: localTarget.feedURL, siteURL: localTarget.siteURL)]
            }
            return []
        }

        let localTarget = MastodonFeedTarget(host: host, scope: .local)
        let federatedTarget = MastodonFeedTarget(host: host, scope: .federated)
        async let localReachable = isTimelineAccessible(localTarget)
        async let federatedReachable = isTimelineAccessible(federatedTarget)
        let (hasLocal, hasFederated) = await (localReachable, federatedReachable)

        if hasLocal && hasFederated {
            return [
                DiscoveredFeed(
                    title: "\(instanceTitle) (Local)",
                    url: localTarget.feedURL,
                    siteURL: localTarget.siteURL
                ),
                DiscoveredFeed(
                    title: "\(instanceTitle) (Federated)",
                    url: federatedTarget.feedURL,
                    siteURL: federatedTarget.siteURL
                )
            ]
        }
        if hasLocal {
            return [
                DiscoveredFeed(
                    title: instanceTitle,
                    url: localTarget.feedURL,
                    siteURL: "https://\(host)"
                )
            ]
        }
        if hasFederated {
            return [
                DiscoveredFeed(
                    title: instanceTitle,
                    url: federatedTarget.feedURL,
                    siteURL: federatedTarget.siteURL
                )
            ]
        }
        return []
    }

    private static func isTimelineAccessible(_ target: MastodonFeedTarget) async -> Bool {
        do {
            _ = try await fetchTimeline(target: target, limit: 1)
            return true
        } catch {
            return false
        }
    }
}
