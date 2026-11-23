import Foundation

nonisolated struct BlueskyModerationPreferences: Sendable, Equatable {

    enum LabelVisibility: String, Sendable, Equatable {
        case ignore
        case show
        case warn
        case hide
    }

    struct MutedWord: Sendable, Equatable {
        let value: String
        let targets: Set<String>
        let expiresAt: Date?

        func isActive(at now: Date = Date()) -> Bool {
            guard let expiresAt else { return true }
            return expiresAt > now
        }
    }

    let isSignedIn: Bool
    let adultContentEnabled: Bool
    let labelPreferences: [String: LabelVisibility]
    let labelerDIDs: [String]
    let mutedWords: [MutedWord]

    static let signedOut = BlueskyModerationPreferences(
        isSignedIn: false,
        adultContentEnabled: false,
        labelPreferences: [:],
        labelerDIDs: [],
        mutedWords: []
    )

    static let signedInDefault = BlueskyModerationPreferences(
        isSignedIn: true,
        adultContentEnabled: false,
        labelPreferences: [:],
        labelerDIDs: [],
        mutedWords: []
    )

    static func parse(preferences: [[String: Any]]) -> BlueskyModerationPreferences {
        var adultContentEnabled = false
        var labelPreferences: [String: LabelVisibility] = [:]
        var labelerDIDs: [String] = []
        var mutedWords: [MutedWord] = []

        for item in preferences {
            guard let type = item["$type"] as? String else { continue }
            switch type {
            case "app.bsky.actor.defs#adultContentPref":
                adultContentEnabled = (item["enabled"] as? Bool) ?? false

            case "app.bsky.actor.defs#contentLabelPref":
                guard let label = item["label"] as? String, !label.isEmpty,
                      let rawVisibility = item["visibility"] as? String,
                      let visibility = LabelVisibility(rawValue: rawVisibility) else { continue }
                labelPreferences[label.lowercased()] = visibility

            case "app.bsky.actor.defs#labelersPref":
                if let labelers = item["labelers"] as? [[String: Any]] {
                    for labeler in labelers {
                        if let did = labeler["did"] as? String, !did.isEmpty, !labelerDIDs.contains(did) {
                            labelerDIDs.append(did)
                        }
                    }
                }

            case "app.bsky.actor.defs#mutedWordsPref":
                if let items = item["items"] as? [[String: Any]] {
                    for wordItem in items {
                        guard let value = wordItem["value"] as? String, !value.isEmpty else { continue }
                        let targets = Set((wordItem["targets"] as? [String]) ?? ["content", "tag"])
                        let expiresAt = (wordItem["expiresAt"] as? String).flatMap(parseISO8601Date(_:))
                        mutedWords.append(MutedWord(value: value, targets: targets, expiresAt: expiresAt))
                    }
                }

            default:
                continue
            }
        }

        return BlueskyModerationPreferences(
            isSignedIn: true,
            adultContentEnabled: adultContentEnabled,
            labelPreferences: labelPreferences,
            labelerDIDs: labelerDIDs,
            mutedWords: mutedWords
        )
    }

    private static func parseISO8601Date(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }
}
