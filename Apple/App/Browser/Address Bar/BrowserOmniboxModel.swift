import Observation
import SwiftUI
import Hanami

/// Editing state for the address field. The field itself lives in the bottom
/// toolbar so it gets the system's glass, while the suggestions render in an
/// overlay above it, so both need to read the same text.
@MainActor
@Observable
final class BrowserOmniboxModel {

    /// Used opening and closing alike: closing used to skip the animation,
    /// so the overlay vanished instead of fading.
    static let transition: Animation = .smooth(duration: 0.25)

    static let queryDebounce: Duration = .milliseconds(150)

    var text: String = ""
    /// The trimmed text once typing pauses. Results follow this rather than
    /// `text`, so a keystroke only redraws the field.
    var query: String = ""
    var contentMatches: [Article] = []
    /// The suggestion the arrow keys have moved to, on hardware keyboards.
    var selectedSuggestionID: String?
    var discovery: FeedDiscoverySession?
    var requestedSheet: BrowserSheetKind?
    private(set) var isActive: Bool = false

    func activate(with query: String = "") {
        text = query
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        contentMatches = []
        selectedSuggestionID = nil
        isActive = true
    }

    func updateQuery() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != query else { return }
        if !trimmed.isEmpty {
            try? await Task.sleep(for: BrowserOmniboxModel.queryDebounce)
            guard !Task.isCancelled else { return }
        }
        query = trimmed
    }

    func deactivate() {
        isActive = false
        text = ""
        query = ""
        contentMatches = []
        discovery = nil
        selectedSuggestionID = nil
    }
}
