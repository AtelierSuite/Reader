import Hanami
import SwiftUI

struct WebFeedRow: View {

    let feed: Feed
    let onEdit: () -> Void
    let onExport: () -> Void

    private var needsRepair: Bool {
        guard let recipe = PetalStore.shared.recipe(forFeedURL: feed.url) else { return false }
        return PetalStore.shared.needsRepair(recipe.id)
    }

    var body: some View {
        HStack(spacing: 10) {
            FeedIconView(feed: feed, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(feed.title)
                    .lineLimit(1)
                Text(feed.siteURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if needsRepair {
                    Label(String(localized: "Manage.NeedsRepair", table: "Petal"),
                          systemImage: "exclamationmark.triangle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Button(String(localized: "FeedEdit.EditRecipe", table: "Petal"),
                   systemImage: "wand.and.stars", action: onEdit)
            Button(String(localized: "Manage.Export", table: "Petal"),
                   systemImage: "square.and.arrow.up", action: onExport)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.vertical, 2)
    }
}
