import SwiftUI

/// The pencil sits beside the capsule as its own glass circle, and splits
/// into Select and Done while editing.
struct FanOutCapsuleContent: View {

    @Environment(FollowingEditModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            FollowingLocationLabel()
            if !model.isEditing {
                AddFeedMenu()
                    .transition(.blurReplace)
            }
        }
        .padding(.leading, BarMetrics.contentInset)
        .padding(.trailing, model.isEditing ? BarMetrics.contentInset : 6)
    }
}

struct FanOutCircles: View {

    @Environment(FollowingEditModel.self) private var model
    let glassNamespace: Namespace.ID

    var body: some View {
        switch model.mode {
        case .browsing:
            BarCircleButton(title: "Edit", systemImage: "pencil", isEnabled: !model.feeds.isEmpty) {
                model.beginEditing()
            }
            .glassEffectID("primary", in: glassNamespace)
        case .editing:
            BarCircleButton(title: "Select", systemImage: "checkmark.circle") {
                model.toggleSelectMode()
            }
            .glassEffectID("primary", in: glassNamespace)
            BarCircleButton(title: "Done", systemImage: "checkmark", isProminent: true) {
                model.endEditing()
            }
            .glassEffectID("secondary", in: glassNamespace)
        case .selecting:
            BarCircleButton(title: "Edit Selected", systemImage: "pencil", isEnabled: !model.selectedIDs.isEmpty) {
                model.isPresentingBulkEdit = true
            }
            .glassEffectID("primary", in: glassNamespace)
            BarCircleButton(
                title: "Delete Selected",
                systemImage: "trash",
                isDestructive: true,
                isEnabled: !model.selectedIDs.isEmpty
            ) {
                model.isPresentingBulkDelete = true
            }
            .glassEffectID("secondary", in: glassNamespace)
            BarCircleButton(title: "Cancel", systemImage: "xmark") {
                model.toggleSelectMode()
            }
            .glassEffectID("tertiary", in: glassNamespace)
        }
    }
}
