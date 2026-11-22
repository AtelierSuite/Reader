import SwiftUI
import Hanami

struct BrowserOmniboxFeedGrid: View {

    static let columnCount = 4
    static let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)

    let suggestions: [BrowserSuggestion]
    let selectedSuggestionID: String?
    let horizontalPadding: CGFloat
    let apply: (BrowserSuggestion) -> Void

    var body: some View {
        LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 16) {
            ForEach(suggestions) { suggestion in
                if case .feed(let feed) = suggestion.kind {
                    Button {
                        apply(suggestion)
                    } label: {
                        FollowingFeedGridCell(feed: feed)
                            .padding(4)
                            .background(
                                suggestion.id == selectedSuggestionID ? Color.accentColor.opacity(0.15) : .clear,
                                in: .rect(cornerRadius: 12)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(suggestion.id == selectedSuggestionID ? .isSelected : [])
                    .id(suggestion.id)
                }
            }
        }
        .padding(.horizontal, horizontalPadding - 4)
        .padding(.vertical, 4)
    }
}
