import Hanami
import SwiftUI

struct BlueskySavedFeedsSheet: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.dismiss) private var dismiss

    @State private var savedFeeds: [BlueskySavedFeed] = []
    @State private var selectedFeedIDs: Set<String> = []
    @State private var isLoading = true
    @State private var isImporting = false
    @State private var loadError: String?

    private var importableFeeds: [BlueskySavedFeed] {
        savedFeeds.filter { !feedManager.hasBlueskyFeed(url: $0.feedURL) }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "Bluesky.ImportSavedFeeds.Title", table: "Integrations"))
                .inlineNavigationTitle()
                .sheetActions {
                    Button(role: .cancel) {
                        dismiss()
                    }
                    .disabled(isImporting)
                } trailing: {
                    Button(String(localized: "Bluesky.ImportSavedFeeds.Import", table: "Integrations")) {
                        importSelectedFeeds()
                    }
                    .disabled(selectedFeedIDs.isEmpty || isImporting || isLoading)
                }
        }
        .task {
            await loadSavedFeeds()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text(String(localized: "Bluesky.ImportSavedFeeds.Loading", table: "Integrations"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let loadError {
            ContentUnavailableView {
                Label(
                    String(localized: "Bluesky.ImportSavedFeeds.ErrorTitle", table: "Integrations"),
                    systemImage: "exclamationmark.triangle"
                )
            } description: {
                Text(loadError)
            } actions: {
                Button(String(localized: "Bluesky.ImportSavedFeeds.Retry", table: "Integrations")) {
                    Task { await loadSavedFeeds() }
                }
            }
        } else if savedFeeds.isEmpty {
            ContentUnavailableView(
                String(localized: "Bluesky.ImportSavedFeeds.EmptyTitle", table: "Integrations"),
                systemImage: "tray",
                description: Text(String(localized: "Bluesky.ImportSavedFeeds.EmptyDescription", table: "Integrations"))
            )
        } else {
            List {
                let pinnedFeeds = savedFeeds.filter(\.isPinned)
                let otherFeeds = savedFeeds.filter { !$0.isPinned }
                if !pinnedFeeds.isEmpty {
                    Section(String(localized: "Bluesky.ImportSavedFeeds.PinnedSection", table: "Integrations")) {
                        ForEach(pinnedFeeds) { savedFeed in
                            savedFeedRow(savedFeed)
                        }
                    }
                }
                if !otherFeeds.isEmpty {
                    Section(String(localized: "Bluesky.ImportSavedFeeds.SavedSection", table: "Integrations")) {
                        ForEach(otherFeeds) { savedFeed in
                            savedFeedRow(savedFeed)
                        }
                    }
                }
            }
        }
    }

    private func savedFeedRow(_ savedFeed: BlueskySavedFeed) -> some View {
        let alreadyAdded = feedManager.hasBlueskyFeed(url: savedFeed.feedURL)
        let isSelected = selectedFeedIDs.contains(savedFeed.id)
        return Button {
            guard !alreadyAdded else { return }
            if isSelected {
                selectedFeedIDs.remove(savedFeed.id)
            } else {
                selectedFeedIDs.insert(savedFeed.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: alreadyAdded || isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(alreadyAdded ? Color.secondary : (isSelected ? Color.accentColor : Color.secondary))
                VStack(alignment: .leading, spacing: 2) {
                    Text(savedFeed.title)
                        .foregroundStyle(alreadyAdded ? .secondary : .primary)
                    if let subtitle = savedFeed.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if alreadyAdded {
                    Text(String(localized: "Bluesky.ImportSavedFeeds.Added", table: "Integrations"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(alreadyAdded || isImporting)
    }

    private func loadSavedFeeds() async {
        isLoading = true
        loadError = nil
        do {
            let fetched = try await BlueskyProvider.fetchSavedFeeds()
            savedFeeds = fetched
            selectedFeedIDs = Set(
                fetched
                    .filter { $0.isPinned && !feedManager.hasBlueskyFeed(url: $0.feedURL) }
                    .map(\.id)
            )
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func importSelectedFeeds() {
        let chosen = importableFeeds.filter { selectedFeedIDs.contains($0.id) }
        guard !chosen.isEmpty else { return }
        isImporting = true
        Task {
            _ = await feedManager.addBlueskySavedFeeds(chosen)
            isImporting = false
            dismiss()
        }
    }
}
