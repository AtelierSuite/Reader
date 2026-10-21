import EnhancedNavigation
import SwiftUI

/// The Following page's controls in the compact address capsule: Edit beside
/// the Add Feed menu while browsing, and the edit and selection controls
/// across the whole capsule while editing.
struct BrowserFollowingBarControls: View {

    @Environment(\.browserOmniboxTakesOver) private var takesOver
    let actions: BrowserFollowingActions

    var body: some View {
        if takesOver {
            Group {
                if actions.isSelecting {
                    selectingControls
                } else {
                    editingControls
                }
            }
            .labelStyle(.iconOnly)
            .frame(maxWidth: .infinity)
            .transition(.blurReplace)
        } else {
            browsingControls
                .transition(.blurReplace)
        }
    }

    private var browsingControls: some View {
        HStack(spacing: 0) {
            if let beginEditing = actions.beginEditing {
                Button(action: beginEditing) {
                    Label(String(localized: "FeedList.Edit", table: "Feeds"), systemImage: "pencil")
                        .padding(.horizontal, 6)
                        .frame(minHeight: TabBottomBarMetrics.itemHeight)
                        .contentShape(.rect)
                }
            }
            Menu {
                Button(action: actions.addFeed) {
                    Label(String(localized: "FeedList.Empty.AddFeed", table: "Feeds"),
                          systemImage: "plus")
                }
            } label: {
                BrowserOmniboxMenuLabel(title: String(localized: "Tabs.More"), systemImage: "ellipsis")
            }
        }
    }

    private var editingControls: some View {
        HStack(spacing: 0) {
            textButton(String(localized: "FeedList.Select", table: "Feeds"),
                       edge: .leading, action: actions.toggleSelectMode)
            Spacer(minLength: 0)
            textButton(String(localized: "Shared.Done"), edge: .trailing, action: actions.endEditing)
                .fontWeight(.semibold)
        }
    }

    private var selectingControls: some View {
        HStack(spacing: 0) {
            textButton(String(localized: "Shared.Cancel"), edge: .leading, action: actions.toggleSelectMode)
            Spacer(minLength: 0)
            Group {
                iconButton(String(localized: "FeedList.Selection.Edit", table: "Feeds"),
                           systemImage: "pencil", action: actions.editSelected)
                iconButton(String(localized: "FeedList.Selection.Delete", table: "Feeds"),
                           systemImage: "trash", action: actions.deleteSelected)
                    .foregroundStyle(actions.selectedCount > 0 ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
            }
            .disabled(actions.selectedCount == 0)
        }
        .padding(.trailing, BrowserAddressItem.contentInset - Self.iconButtonInset)
        .overlay {
            Text(String(localized: "FeedList.Selection.Count.\(actions.selectedCount)", table: "Feeds"))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .allowsHitTesting(false)
        }
    }

    /// Runs its tap target out to the capsule's end on the side it sits.
    private func textButton(_ title: String, edge: HorizontalEdge, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .padding(edge == .leading ? .leading : .trailing, BrowserAddressItem.contentInset + 3)
                .padding(edge == .leading ? .trailing : .leading, 8)
                .frame(minHeight: TabBottomBarMetrics.itemHeight)
                .contentShape(.rect)
        }
    }

    private func iconButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .padding(.horizontal, Self.iconButtonInset)
                .frame(minHeight: TabBottomBarMetrics.itemHeight)
                .contentShape(.rect)
        }
    }

    private static let iconButtonInset: CGFloat = 9
}
