import Foundation

public extension BlueskyProvider {

    nonisolated static func fetchSavedFeeds() async throws -> [BlueskySavedFeed] {
        let root = try await xrpc(
            "app.bsky.actor.getPreferences",
            query: [],
            requireAuth: true,
            useAppViewProxy: false,
            includeLabelers: false
        )
        let preferences = (root["preferences"] as? [[String: Any]]) ?? []
        guard let savedPref = preferences.first(where: {
            ($0["$type"] as? String) == "app.bsky.actor.defs#savedFeedsPrefV2"
        }),
              let rawItems = savedPref["items"] as? [[String: Any]] else {
            return []
        }

        let entries = rawItems.compactMap(parseSavedFeedEntry(_:))
        let feedURIs = entries.filter { $0.type == "feed" }.map(\.value)
        let listURIs = entries.filter { $0.type == "list" }.map(\.value)

        let generatorsByURI = await fetchFeedGenerators(uris: feedURIs)
        let listsByURI = await fetchLists(uris: listURIs)

        var resolved: [BlueskySavedFeed] = []
        var seenFeedURLs = Set<String>()

        for entry in entries {
            guard let item = buildSavedFeed(
                from: entry, generatorsByURI: generatorsByURI, listsByURI: listsByURI
            ) else { continue }
            if seenFeedURLs.insert(item.feedURL).inserted {
                resolved.append(item)
            }
        }

        let pinned = resolved.filter(\.isPinned)
        let unpinned = resolved.filter { !$0.isPinned }
        return pinned + unpinned
    }

    private struct SavedFeedEntry {
        let type: String
        let value: String
        let isPinned: Bool
    }

    private struct ResolvedSavedMetadata {
        let title: String
        let subtitle: String?
        let avatarURL: String?
    }

    private nonisolated static func parseSavedFeedEntry(_ item: [String: Any]) -> SavedFeedEntry? {
        guard let type = item["type"] as? String,
              let value = item["value"] as? String,
              !value.isEmpty else { return nil }
        return SavedFeedEntry(
            type: type,
            value: value,
            isPinned: (item["pinned"] as? Bool) ?? false
        )
    }

    private nonisolated static func buildSavedFeed(
        from entry: SavedFeedEntry,
        generatorsByURI: [String: ResolvedSavedMetadata],
        listsByURI: [String: ResolvedSavedMetadata]
    ) -> BlueskySavedFeed? {
        switch entry.type {
        case "timeline":
            let target = BlueskyFeedTarget.following
            return BlueskySavedFeed(
                id: target.feedURL,
                kind: .following,
                title: String(localized: "Bluesky.Following.FeedTitle", table: "Integrations"),
                subtitle: nil,
                avatarURL: nil,
                feedURL: target.feedURL,
                siteURL: target.siteURL,
                isPinned: entry.isPinned
            )

        case "feed":
            guard let target = BlueskyFeedTarget(atURI: entry.value), target.kind == .feed else {
                return nil
            }
            let metadata = generatorsByURI[entry.value]
            return BlueskySavedFeed(
                id: target.feedURL,
                kind: .feed,
                title: metadata?.title ?? target.recordKey,
                subtitle: metadata?.subtitle,
                avatarURL: metadata?.avatarURL,
                feedURL: target.feedURL,
                siteURL: target.siteURL,
                isPinned: entry.isPinned
            )

        case "list":
            guard let target = BlueskyFeedTarget(atURI: entry.value), target.kind == .list else {
                return nil
            }
            let metadata = listsByURI[entry.value]
            return BlueskySavedFeed(
                id: target.feedURL,
                kind: .list,
                title: metadata?.title ?? target.recordKey,
                subtitle: metadata?.subtitle,
                avatarURL: metadata?.avatarURL,
                feedURL: target.feedURL,
                siteURL: target.siteURL,
                isPinned: entry.isPinned
            )

        default:
            return nil
        }
    }

    private nonisolated static func fetchFeedGenerators(
        uris: [String]
    ) async -> [String: ResolvedSavedMetadata] {
        guard !uris.isEmpty else { return [:] }
        var results: [String: ResolvedSavedMetadata] = [:]
        let chunkSize = 25
        var startIndex = 0
        while startIndex < uris.count {
            let endIndex = min(startIndex + chunkSize, uris.count)
            let chunk = Array(uris[startIndex..<endIndex])
            let query = chunk.map { URLQueryItem(name: "feeds", value: $0) }
            if let root = try? await xrpc("app.bsky.feed.getFeedGenerators", query: query),
               let feeds = root["feeds"] as? [[String: Any]] {
                for feed in feeds {
                    guard let uri = feed["uri"] as? String else { continue }
                    let displayName = (feed["displayName"] as? String) ?? ""
                    let creatorHandle = (feed["creator"] as? [String: Any])?["handle"] as? String
                    let avatar = (feed["avatar"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    results[uri] = ResolvedSavedMetadata(
                        title: displayName.isEmpty ? uri : displayName,
                        subtitle: creatorHandle.map { "@\($0)" },
                        avatarURL: avatar
                    )
                }
            }
            startIndex = endIndex
        }
        return results
    }

    private nonisolated static func fetchLists(
        uris: [String]
    ) async -> [String: ResolvedSavedMetadata] {
        guard !uris.isEmpty else { return [:] }
        var results: [String: ResolvedSavedMetadata] = [:]
        for uri in uris {
            let query = [
                URLQueryItem(name: "list", value: uri),
                URLQueryItem(name: "limit", value: "1")
            ]
            if let root = try? await xrpc("app.bsky.graph.getList", query: query),
               let list = root["list"] as? [String: Any] {
                let name = (list["name"] as? String) ?? ""
                let creatorHandle = (list["creator"] as? [String: Any])?["handle"] as? String
                let avatar = (list["avatar"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                results[uri] = ResolvedSavedMetadata(
                    title: name.isEmpty ? uri : name,
                    subtitle: creatorHandle.map { "@\($0)" },
                    avatarURL: avatar
                )
            }
        }
        return results
    }
}
