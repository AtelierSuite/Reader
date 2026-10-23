import SwiftUI

/// The Following page's top bar controls inside classic tabs, spread out as
/// separate buttons rather than gathered into the omnibox's menu.
struct FollowingClassicToolbar: ToolbarContent {

    let actions: BrowserFollowingActions

    var body: some ToolbarContent {
        if actions.isSelecting {
            selectingItems
        } else if actions.isEditing {
            editingItems
        } else {
            browsingItems
        }
    }

    @ToolbarContentBuilder
    private var browsingItems: some ToolbarContent {
        if let beginEditing = actions.beginEditing {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: beginEditing) {
                    Label(String(localized: "FeedList.Edit", table: "Feeds"), systemImage: "pencil")
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: actions.addFeed) {
                Label(String(localized: "FeedList.Empty.AddFeed", table: "Feeds"), systemImage: "plus")
            }
            .buttonStyle(.glassProminent)
        }
    }

    @ToolbarContentBuilder
    private var editingItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(String(localized: "FeedList.Select", table: "Feeds"), action: actions.toggleSelectMode)
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button(role: .confirm, action: actions.endEditing)
        }
    }

    @ToolbarContentBuilder
    private var selectingItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: actions.editSelected) {
                Label(String(localized: "FeedList.Selection.Edit", table: "Feeds"), systemImage: "pencil")
            }
            .disabled(actions.selectedCount == 0)
            Button(role: .destructive, action: actions.deleteSelected) {
                Label(String(localized: "FeedList.Selection.Delete", table: "Feeds"), systemImage: "trash")
            }
            .tint(.red)
            .disabled(actions.selectedCount == 0)
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button(role: .cancel, action: actions.toggleSelectMode)
        }
    }
}
