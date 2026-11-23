import Foundation

nonisolated enum BlueskyModeration {

    enum Decision: Equatable {
        case show
        case hideMedia
        case hide
    }

    static let unauthenticatedLabel = "!no-unauthenticated"
    static let alwaysHiddenLabels: Set<String> = ["!hide", "!takedown"]
    static let adultLabels: Set<String> = ["porn", "sexual", "nudity"]
    static let hiddenMediaLabels: Set<String> = ["graphic-media", "gore"]

    static func decision(
        labels: Any?,
        record: [String: Any]?,
        author: [String: Any]?,
        preferences: BlueskyModerationPreferences = .signedOut
    ) -> Decision {
        let authorLabels = (author?["labels"] as? [[String: Any]]) ?? []
        if !preferences.isSignedIn,
           authorLabels.contains(where: { ($0["val"] as? String) == unauthenticatedLabel }) {
            return .hide
        }
        let authorDID = author?["did"] as? String
        let accountLabels = authorLabels
            .filter { authorDID != nil && ($0["uri"] as? String) == authorDID }
            .compactMap { $0["val"] as? String }
        let values = Set(
            (labelValues(labels) + selfLabelValues(record) + accountLabels).map { $0.lowercased() }
        )

        if !preferences.isSignedIn, values.contains(unauthenticatedLabel) {
            return .hide
        }
        if !values.isDisjoint(with: alwaysHiddenLabels) {
            return .hide
        }
        if matchesMutedWord(record: record, preferences: preferences) {
            return .hide
        }

        var result: Decision = .show
        for label in values {
            let labelDecision = decision(forLabel: label, preferences: preferences)
            if labelDecision == .hide { return .hide }
            if labelDecision == .hideMedia { result = .hideMedia }
        }
        return result
    }

    private static func decision(
        forLabel label: String,
        preferences: BlueskyModerationPreferences
    ) -> Decision {
        if adultLabels.contains(label) {
            guard preferences.adultContentEnabled else { return .hide }
            if let visibility = preferences.labelPreferences[label] {
                return decision(forVisibility: visibility)
            }
            return .hideMedia
        }
        if let visibility = preferences.labelPreferences[label] {
            return decision(forVisibility: visibility)
        }
        if hiddenMediaLabels.contains(label) {
            return .hideMedia
        }
        return .show
    }

    private static func decision(
        forVisibility visibility: BlueskyModerationPreferences.LabelVisibility
    ) -> Decision {
        switch visibility {
        case .ignore, .show: .show
        case .warn: .hideMedia
        case .hide: .hide
        }
    }

    private static func matchesMutedWord(
        record: [String: Any]?,
        preferences: BlueskyModerationPreferences
    ) -> Bool {
        guard preferences.isSignedIn, !preferences.mutedWords.isEmpty, let record else { return false }
        let now = Date()
        let activeWords = preferences.mutedWords.filter { $0.isActive(at: now) }
        guard !activeWords.isEmpty else { return false }

        let text = ((record["text"] as? String) ?? "").lowercased()
        let tags = Set(extractTags(from: record).map { $0.lowercased() })

        for mutedWord in activeWords {
            let needle = mutedWord.value.lowercased()
            if mutedWord.targets.contains("content"), !text.isEmpty, text.contains(needle) {
                return true
            }
            if mutedWord.targets.contains("tag"), tags.contains(needle) {
                return true
            }
        }
        return false
    }

    private static func extractTags(from record: [String: Any]) -> [String] {
        var tags = (record["tags"] as? [String]) ?? []
        if let facets = record["facets"] as? [[String: Any]] {
            for facet in facets {
                guard let features = facet["features"] as? [[String: Any]] else { continue }
                for feature in features where (feature["$type"] as? String) == "app.bsky.richtext.facet#tag" {
                    if let tag = feature["tag"] as? String, !tag.isEmpty {
                        tags.append(tag)
                    }
                }
            }
        }
        return tags
    }

    private static func labelValues(_ labels: Any?) -> [String] {
        ((labels as? [[String: Any]]) ?? []).compactMap { $0["val"] as? String }
    }

    private static func selfLabelValues(_ record: [String: Any]?) -> [String] {
        guard let selfLabels = record?["labels"] as? [String: Any] else { return [] }
        return labelValues(selfLabels["values"])
    }
}
