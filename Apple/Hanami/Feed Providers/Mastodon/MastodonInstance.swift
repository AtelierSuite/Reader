import Foundation

nonisolated struct MastodonInstance: Decodable, Sendable {
    let title: String?
    let domain: String?
    let description: String?
    let icon: [MastodonInstanceIcon]?

    var displayTitle: String? {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var customIconURL: String? {
        guard let customIcon = icon?.last(where: { !$0.src.contains("/packs/assets/") })?.src,
              !customIcon.isEmpty else {
            return nil
        }
        return customIcon
    }
}

nonisolated struct MastodonInstanceIcon: Decodable, Sendable {
    let src: String
    let size: String?
}
