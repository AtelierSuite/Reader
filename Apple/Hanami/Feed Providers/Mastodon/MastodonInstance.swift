import Foundation

nonisolated struct MastodonInstance: Decodable, Sendable {
    let title: String?
    let domain: String?
    let description: String?
    let thumbnail: MastodonInstanceThumbnail?
    let icon: [MastodonInstanceIcon]?

    var displayTitle: String? {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var preferredIconURL: String? {
        if let customIcon = icon?.last(where: { !$0.src.contains("/packs/assets/") })?.src,
           !customIcon.isEmpty {
            return customIcon
        }
        if let thumbnailURL = thumbnail?.url, !thumbnailURL.isEmpty {
            return thumbnailURL
        }
        return nil
    }
}

nonisolated struct MastodonInstanceThumbnail: Decodable, Sendable {
    let url: String?
}

nonisolated struct MastodonInstanceIcon: Decodable, Sendable {
    let src: String
    let size: String?
}
