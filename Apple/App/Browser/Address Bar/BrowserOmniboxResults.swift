import SwiftUI
import Hanami

/// Everything the omnibox finds for the typed text, ordered so the closest
/// matches sit nearest the field: discovered feeds, then followed feeds, then
/// lists and content.
struct BrowserOmniboxResults: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserOmniboxModel.self) private var omnibox

    let suggestions: [BrowserSuggestion]
    let selectedSuggestionID: String?
    let horizontalPadding: CGFloat
    let apply: (BrowserSuggestion) -> Void

    private var discovery: BrowserOmniboxDiscovery {
        BrowserOmniboxDiscovery(omnibox: omnibox, feedManager: feedManager)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let session = omnibox.discovery {
                BrowserOmniboxDiscoveredSection(
                    session: session,
                    horizontalPadding: horizontalPadding,
                    onAdd: discovery.add,
                    onGenerateWebFeed: discovery.generateWebFeed
                )
            }
            ForEach(BrowserSuggestion.Section.allCases, id: \.rawValue) { section in
                let sectionSuggestions = suggestions.filter { $0.section == section }
                if !sectionSuggestions.isEmpty {
                    BrowserOmniboxSectionHeader(title: section.title)
                        .padding(.horizontal, horizontalPadding)
                    if section == .feeds {
                        BrowserOmniboxFeedGrid(
                            suggestions: sectionSuggestions,
                            selectedSuggestionID: selectedSuggestionID,
                            horizontalPadding: horizontalPadding,
                            apply: apply
                        )
                    } else {
                        ForEach(sectionSuggestions) { suggestion in
                            BrowserSuggestionRow(suggestion: suggestion) { apply(suggestion) }
                                .padding(.horizontal, horizontalPadding)
                                .padding(.vertical, 11)
                                .background(
                                    suggestion.id == selectedSuggestionID ? Color.accentColor.opacity(0.15) : .clear
                                )
                                .accessibilityAddTraits(suggestion.id == selectedSuggestionID ? .isSelected : [])
                                .id(suggestion.id)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 12)
        .animation(.smooth.speed(2.0), value: omnibox.discovery?.isSearching)
        .animation(.smooth.speed(2.0), value: feedManager.feeds.count)
    }
}
