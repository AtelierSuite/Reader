import SwiftUI
import Hanami

extension FollowingPage {

    var browserFollowingActions: BrowserFollowingActions {
        let hasSomethingToEdit = !feedManager.feeds.isEmpty
        return BrowserFollowingActions(
            addFeed: { isPresentingAddFeedSheet = true },
            beginEditing: hasSomethingToEdit ? { isEditingFeeds = true } : nil,
            isEditing: isEditingFeeds,
            isSelecting: isSelectingFeeds,
            toggleSelectMode: { toggleSelectMode() },
            endEditing: { exitEditMode() },
            selectedCount: selectedFeedIDs.count,
            editSelected: { isPresentingBulkEditSheet = true },
            deleteSelected: { isPresentingBulkDeleteAlert = true }
        )
    }

    /// The wide layout gives the page one button for its menu, so the edit
    /// controls only spread out in the compact capsule.
    @ViewBuilder
    var followingPageMenu: some View {
        if BrowserLayout.usesWideTabs {
            BrowserFollowingMenu(actions: browserFollowingActions)
        } else {
            BrowserFollowingBarControls(actions: browserFollowingActions)
        }
    }
}
