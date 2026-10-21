import SwiftUI
import Hanami

struct BrowserTodayQuickAccessCell: View {
    let title: String
    let symbolName: String
    var section: FeedSection?

    private let iconCornerRadius: CGFloat = 12

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            BrowserTodayQuickAccessIcon(symbolName: symbolName, section: section)
                .contentShape(
                    .hoverEffect,
                    AnyShape(RoundedRectangle(cornerRadius: iconCornerRadius))
                )
                .hoverEffect(.highlight)

            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.middle)
                .wiggleRotation()
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
    }
}
