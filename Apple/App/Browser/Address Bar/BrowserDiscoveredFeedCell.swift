import SwiftUI
import Hanami

struct BrowserDiscoveredFeedCell: View {

    static let iconSize: CGFloat = 56
    static let iconCornerRadius: CGFloat = 12

    let feed: DiscoveredFeed
    let isAdding: Bool
    let onAdd: () -> Void
    @State private var icon: UIImage?

    private var domain: String {
        let siteHost = URL(string: feed.siteURL)?.host()
        return siteHost ?? URL(string: feed.url)?.host() ?? feed.url
    }

    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: 6) {
                iconView
                    .frame(width: Self.iconSize, height: Self.iconSize)
                    .overlay(alignment: .bottomTrailing) {
                        statusBadge
                            .offset(x: 6, y: 6)
                    }
                Text(feed.title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isAdding)
        .task(id: feed.url) {
            icon = await Iconography.shared.icon(for: domain, siteURL: feed.siteURL)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon {
            IconImage(icon, size: Self.iconSize, cornerRadius: Self.iconCornerRadius)
        } else {
            InitialsAvatarView(feed.title, size: Self.iconSize, cornerRadius: Self.iconCornerRadius)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        Group {
            if isAdding {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.white, Color.accentColor)
            }
        }
        .font(.title3)
        .frame(width: 24, height: 24)
        .background(.background, in: .circle)
    }
}
