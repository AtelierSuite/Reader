import Foundation

/// Signed-out defaults: adult content is hidden and graphic media is withheld.
nonisolated enum BlueskyModeration {

    enum Decision: Equatable {
        case show
        case hideMedia
        case hide
    }

    static let unauthenticatedLabel = "!no-unauthenticated"
    static let hiddenLabels: Set<String> = ["!hide", "porn", "sexual", "nudity"]
    static let hiddenMediaLabels: Set<String> = ["graphic-media", "gore"]

    static func decision(
        labels: Any?, record: [String: Any]?, author: [String: Any]?
    ) -> Decision {
        let authorLabels = (author?["labels"] as? [[String: Any]]) ?? []
        if authorLabels.contains(where: { ($0["val"] as? String) == unauthenticatedLabel }) {
            return .hide
        }
        let authorDID = author?["did"] as? String
        let accountLabels = authorLabels
            .filter { authorDID != nil && ($0["uri"] as? String) == authorDID }
            .compactMap { $0["val"] as? String }
        let values = Set(labelValues(labels) + selfLabelValues(record) + accountLabels)
        if values.contains(unauthenticatedLabel) || !values.isDisjoint(with: hiddenLabels) {
            return .hide
        }
        return values.isDisjoint(with: hiddenMediaLabels) ? .show : .hideMedia
    }

    private static func labelValues(_ labels: Any?) -> [String] {
        ((labels as? [[String: Any]]) ?? []).compactMap { $0["val"] as? String }
    }

    private static func selfLabelValues(_ record: [String: Any]?) -> [String] {
        guard let selfLabels = record?["labels"] as? [String: Any] else { return [] }
        return labelValues(selfLabels["values"])
    }
}
