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
            // A ZStack rather than a Group, which would hand the animation
            // to each branch instead of to the swap between them.
            ZStack {
                if actions.isSelecting {
                    selectingControls
                        .transition(.blurReplace)
                } else {
                    editingControls
                        .transition(.blurReplace)
                }
            }
            .labelStyle(.iconOnly)
            .frame(maxWidth: .infinity)
            .animation(.smooth(duration: 0.35), value: actions.isSelecting)
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

    /// Cancel is a glyph here so the count keeps its room in a capsule
    /// squeezed between Back and Tabs, whatever the language.
    private var selectingControls: some View {
        HStack(spacing: 0) {
            iconButton(String(localized: "Shared.Cancel"), systemImage: "xmark", action: actions.toggleSelectMode)
                .padding(.leading, BrowserAddressItem.contentInset - Self.iconButtonInset)
            Text(String(localized: "FeedList.Selection.Count.\(actions.selectedCount)", table: "Feeds"))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
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
