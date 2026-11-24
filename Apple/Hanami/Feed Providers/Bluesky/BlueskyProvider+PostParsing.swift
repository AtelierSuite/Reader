import Foundation

extension BlueskyProvider {

    nonisolated static func parseFeedViewPost(
        _ entry: [String: Any],
        preferences: BlueskyModerationPreferences = .signedOut
    ) -> ParsedBlueskyPost? {
        if let reason = entry["reason"] as? [String: Any],
           (reason["$type"] as? String) == "app.bsky.feed.defs#reasonRepost" {
            return nil
        }
        guard let post = entry["post"] as? [String: Any],
              let uri = post["uri"] as? String,
              let record = post["record"] as? [String: Any],
              let author = post["author"] as? [String: Any],
              let authorHandle = author["handle"] as? String,
              let postURL = postWebURL(atURI: uri, authorHandle: authorHandle) else { return nil }

        let moderation = BlueskyModeration.decision(
            labels: post["labels"], record: record, author: author, preferences: preferences
        )
        guard moderation != .hide else { return nil }

        let embed = post["embed"] as? [String: Any]
        let media = moderation == .hideMedia ? BlueskyMedia() : extractMedia(from: embed)
        var parsed = ParsedBlueskyPost(
            uri: uri,
            url: postURL,
            text: (record["text"] as? String) ?? "",
            author: (author["displayName"] as? String) ?? "",
            authorHandle: authorHandle,
            images: media.images,
            videoThumbnailURL: media.videoThumbnailURL,
            publishedDate: (record["createdAt"] as? String).flatMap(parseISO8601(_:))
        )
        parsed.quote = quotedRecord(in: embed).flatMap { parseQuote($0, preferences: preferences) }
        return parsed
    }

    private nonisolated static func quotedRecord(in embed: [String: Any]?) -> [String: Any]? {
        switch embed?["$type"] as? String {
        case "app.bsky.embed.record#view":
            return embed?["record"] as? [String: Any]
        case "app.bsky.embed.recordWithMedia#view":
            return (embed?["record"] as? [String: Any])?["record"] as? [String: Any]
        default:
            return nil
        }
    }

    private nonisolated static func parseQuote(
        _ view: [String: Any],
        preferences: BlueskyModerationPreferences
    ) -> ParsedBlueskyQuote? {
        guard (view["$type"] as? String) == "app.bsky.embed.record#viewRecord",
              let uri = view["uri"] as? String, uri.contains("/app.bsky.feed.post/"),
              let author = view["author"] as? [String: Any],
              let authorHandle = author["handle"] as? String,
              let quoteURL = postWebURL(atURI: uri, authorHandle: authorHandle) else { return nil }
        let record = view["value"] as? [String: Any]
        let moderation = BlueskyModeration.decision(
            labels: view["labels"], record: record, author: author, preferences: preferences
        )
        guard moderation != .hide else { return nil }
        let embeds = (view["embeds"] as? [[String: Any]]) ?? []
        let images = moderation == .hideMedia ? [] : embeds.flatMap { extractMedia(from: $0).images }
        return ParsedBlueskyQuote(
            url: quoteURL,
            text: (record?["text"] as? String) ?? "",
            author: (author["displayName"] as? String) ?? "",
            authorHandle: authorHandle,
            images: images
        )
    }

    private nonisolated static func extractMedia(from embed: [String: Any]?) -> BlueskyMedia {
        guard let embed else { return BlueskyMedia() }
        switch embed["$type"] as? String {
        case "app.bsky.embed.images#view":
            return BlueskyMedia(images: parseImages(from: embed))
        case "app.bsky.embed.video#view":
            return BlueskyMedia(videoThumbnailURL: embed["thumbnail"] as? String)
        case "app.bsky.embed.recordWithMedia#view":
            return extractMedia(from: embed["media"] as? [String: Any])
        default:
            return BlueskyMedia()
        }
    }

    private nonisolated static func parseImages(from view: [String: Any]) -> [ParsedBlueskyImage] {
        guard let images = view["images"] as? [[String: Any]] else { return [] }
        return images.compactMap { image in
            guard let thumb = image["thumb"] as? String,
                  let fullsize = image["fullsize"] as? String else { return nil }
            return ParsedBlueskyImage(thumbURL: thumb, fullsizeURL: fullsize, alt: (image["alt"] as? String) ?? "")
        }
    }

    private nonisolated static func postWebURL(atURI: String, authorHandle: String) -> String? {
        guard let rkey = atURI.split(separator: "/").last, !rkey.isEmpty else { return nil }
        return "https://\(host)/profile/\(authorHandle)/post/\(rkey)"
    }

    private nonisolated(unsafe) static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private nonisolated(unsafe) static let iso8601FallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private nonisolated static func parseISO8601(_ value: String) -> Date? {
        iso8601Formatter.date(from: value) ?? iso8601FallbackFormatter.date(from: value)
    }
}

nonisolated struct BlueskyMedia {
    var images: [ParsedBlueskyImage] = []
    var videoThumbnailURL: String?
}
