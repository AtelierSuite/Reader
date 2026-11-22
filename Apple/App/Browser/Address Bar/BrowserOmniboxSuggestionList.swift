import SwiftUI

struct BrowserOmniboxSuggestionList: View {

    let suggestions: [BrowserSuggestion]
    let selectedSuggestionID: String?
    let apply: (BrowserSuggestion) -> Void

    var body: some View {
        ScrollViewReader { scrollProxy in
            ViewThatFits(in: .vertical) {
                rows
                ScrollView {
                    rows
                }
                .defaultScrollAnchor(.top)
            }
            .onChange(of: selectedSuggestionID) {
                if let selectedSuggestionID {
                    scrollProxy.scrollTo(selectedSuggestionID)
                }
            }
        }
    }

    private var rows: some View {
        BrowserOmniboxResults(
            suggestions: suggestions,
            selectedSuggestionID: selectedSuggestionID,
            horizontalPadding: 16,
            apply: apply
        )
    }
}
