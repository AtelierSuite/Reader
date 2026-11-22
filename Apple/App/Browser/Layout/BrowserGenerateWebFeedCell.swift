import SwiftUI

struct BrowserGenerateWebFeedCell: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: BrowserDiscoveredFeedCell.iconCornerRadius)
                    .fill(.fill.tertiary)
                    .frame(
                        width: BrowserDiscoveredFeedCell.iconSize,
                        height: BrowserDiscoveredFeedCell.iconSize
                    )
                    .overlay {
                        Image(systemName: "leaf.fill")
                            .font(.title2)
                            .foregroundStyle(.tint)
                    }
                Text(String(localized: "AddFeed.Generate", table: "Petal"))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
