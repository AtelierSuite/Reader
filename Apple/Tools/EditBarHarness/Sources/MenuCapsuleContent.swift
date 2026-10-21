import SwiftUI

/// Today's behaviour: everything lives in the capsule's one menu.
struct MenuCapsuleContent: View {

    @Environment(FollowingEditModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            FollowingLocationLabel()
            Menu {
                if model.isEditing {
                    editingItems
                } else {
                    browsingItems
                }
            } label: {
                Image(systemName: model.isEditing ? "pencil.circle.fill" : "ellipsis")
                    .frame(width: 36, height: BarMetrics.itemHeight)
                    .contentShape(.rect)
            }
        }
        .padding(.leading, BarMetrics.contentInset)
        .padding(.trailing, 6)
    }

    @ViewBuilder
    private var browsingItems: some View {
        Button("Add Feed", systemImage: "plus") { model.addFeed() }
        if !model.feeds.isEmpty {
            Section {
                Button("Edit", systemImage: "pencil") { model.beginEditing() }
            }
        }
    }

    @ViewBuilder
    private var editingItems: some View {
        if model.mode == .selecting {
            if !model.selectedIDs.isEmpty {
                Button("Edit Selected", systemImage: "pencil") { model.isPresentingBulkEdit = true }
                Button("Delete Selected", systemImage: "trash", role: .destructive) {
                    model.isPresentingBulkDelete = true
                }
                Divider()
            }
            Button("Cancel", systemImage: "xmark", role: .cancel) { model.toggleSelectMode() }
        } else {
            Button("Select", systemImage: "checkmark.circle") { model.toggleSelectMode() }
            Section {
                Button("Done", systemImage: "checkmark") { model.endEditing() }
            }
        }
    }
}
