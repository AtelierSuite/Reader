import Foundation

extension BlueskyProvider {

    public nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
        if isShortLink(url) {
            guard let resolvedURL = await resolveShortLink(url), isProfileURL(resolvedURL) else { return nil }
            return await discoveredFeed(forProfileURL: resolvedURL)
        }
        if let target = BlueskyFeedTarget(pageURL: url) {
            return await discoveredFeed(for: target)
        }
        guard let handle = extractIdentifier(from: url) else { return nil }
        guard let did = await resolveDID(forHandle: handle) ?? handle.asDIDIfValid,
              let profile = await fetchActorProfile(actor: did) else {
            log("BlueskyProfile", "discovery failed for @\(handle)")
            return nil
        }
        return DiscoveredFeed(
            title: profile.displayName ?? "@\(handle)",
            url: feedURL(for: handle),
            siteURL: profileURL(for: handle)?.absoluteString ?? "https://\(host)/profile/\(handle)"
        )
    }

    private nonisolated static func discoveredFeed(for pageTarget: BlueskyFeedTarget) async -> DiscoveredFeed? {
        guard let target = await resolvedTarget(pageTarget) else {
            log("BlueskyFeed", "could not resolve \(pageTarget.actor)")
            return nil
        }
        do {
            let content = try await fetchTargetContent(target, pageCount: 1)
            return DiscoveredFeed(
                title: content.title ?? target.recordKey, url: target.feedURL, siteURL: target.siteURL
            )
        } catch BlueskyAPIError.authenticationRequired {
            log("BlueskyFeed", "\(target.atURI) requires signing in to Bluesky")
            return nil
        } catch {
            log("BlueskyFeed", "discovery failed for \(target.atURI) - \(error)")
            return nil
        }
    }
}
