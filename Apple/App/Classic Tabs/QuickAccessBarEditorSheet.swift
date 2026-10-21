import SwiftUI
import Hanami

struct QuickAccessBarEditorSheet: View {

    let items: [QuickAccessBarItem]

    @Environment(FeedManager.self) private var feedManager
    @SheetDismiss private var dismiss
    @State private var orderedItems: [QuickAccessBarItem] = []
    private let preferences = TodayQuickAccessPreferences.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(orderedItems) { item in
                    Label(item.title, systemImage: item.symbolName)
                }
                .onMove { source, destination in
                    orderedItems.move(fromOffsets: source, toOffset: destination)
                    saveOrder()
                }
            }
            .settingsListStyle()
            .environment(\.editMode, .constant(.active))
            .sheetTitle(String(localized: "Today.QuickAccess.Edit", table: "Home"))
            .compatibleSoftScrollEdgeEffectStyle()
            .sheetActions {
                EmptyView()
            } trailing: {
                Button(role: .confirm) {
                    dismiss()
                }
            }
            .onAppear {
                orderedItems = items
            }
        }
    }

    /// Slots the new order into the positions the bar's items already hold, so
    /// Quick Access items the bar doesn't show keep their places on the start page.
    private func saveOrder() {
        let reorderedItems = orderedItems.map(\.source.quickAccessItem)
        let reorderedIDs = Set(reorderedItems.map(\.id))
        var remainingItems = reorderedItems[...]
        var mergedItems = preferences.ordered(TodayQuickAccessItem.browserItems(in: feedManager)).map { item in
            guard reorderedIDs.contains(item.id), let nextItem = remainingItems.popFirst() else { return item }
            return nextItem
        }
        mergedItems.append(contentsOf: remainingItems)
        preferences.saveOrder(mergedItems)
    }
}
