import Foundation

extension BlueskyProvider: MetadataProvider {

    public nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        profileHandle(from: url) != nil || BlueskyFeedTarget(pageURL: url) != nil
    }

    public static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        if let pageTarget = BlueskyFeedTarget(pageURL: url) {
            guard let target = await resolvedTarget(pageTarget),
                  let metadata = try? await fetchTargetMetadata(target) else { return nil }
            return FetchedFeedMetadata(
                displayName: metadata.title,
                iconURL: metadata.avatarURL.flatMap(URL.init(string:))
            )
        }
        guard let handle = extractIdentifier(from: url) else { return nil }
        let result = await BlueskyProvider().fetchProfile(handle: handle)
        return FetchedFeedMetadata(
            displayName: result.displayName,
            iconURL: result.profileImageURL.flatMap(URL.init(string:))
        )
    }
}
