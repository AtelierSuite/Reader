import SwiftUI

struct HomeSectionBarButton: View {

    let tab: HomeSectionBarItem
    let isSelected: Bool
    let selectedTextColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Reserve the semibold width always so selecting a tab doesn't widen
            // it (regular -> semibold). A width change resizes the scroll content
            // and makes the horizontal ScrollView reset its offset to 0.
            Text(tab.title)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .hidden()
                .overlay {
                    Text(tab.title)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? selectedTextColor : Color.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .fixedSize(horizontal: true, vertical: false)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
