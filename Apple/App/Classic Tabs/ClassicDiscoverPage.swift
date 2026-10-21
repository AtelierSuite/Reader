import SwiftUI
import Hanami

struct ClassicDiscoverPage: View {

    @Environment(FeedManager.self) private var feedManager
    @State private var searchText = ""
    @State private var query = ""

    var body: some View {
        Group {
            if query.isEmpty {
                DiscoverView(searchText: $searchText)
                    .navigationTitle("Tabs.Discover")
                    .toolbarTitleDisplayMode(.inlineLarge)
                    .sakuraBackground()
            } else {
                BrowserSearchResultsView(query: query, recordsSearchTerm: false)
            }
        }
        .searchable(text: $searchText, prompt: String(localized: "Prompt", table: "Search"))
        .onSubmit(of: .search) {
            let submitted = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !submitted.isEmpty else { return }
            feedManager.recordSearchTerm(submitted)
        }
        .task(id: searchText) {
            let typed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !typed.isEmpty {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
            }
            withAnimation(.smooth.speed(2.0)) {
                query = typed
            }
        }
    }
}
