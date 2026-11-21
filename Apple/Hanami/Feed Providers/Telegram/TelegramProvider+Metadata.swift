import Foundation

extension TelegramProvider: MetadataProvider {

    public nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isProfileURL(url)
    }

    public static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let channel = extractIdentifier(from: url),
              let result = try? await TelegramProvider().fetchChannel(channel) else {
            return nil
        }
        return FetchedFeedMetadata(
            displayName: result.title,
            iconURL: result.avatarURL.flatMap(URL.init(string:))
        )
    }
}
