import SwiftUI
import Hanami

struct FollowingListGridCell: View {

    @Environment(FeedManager.self) var feedManager
    let list: FeedList
    var isWiggling: Bool = false
    var onDelete: (() -> Void)?
    var onTap: (() -> Void)?

    private let iconCornerRadius: CGFloat = 12

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            FollowingListIcon(list: list)
                .contentShape(
                    .hoverEffect,
                    AnyShape(RoundedRectangle(cornerRadius: iconCornerRadius))
                )
                .hoverEffect(.highlight)
                .overlay(alignment: .topTrailing) {
                    if !isWiggling, feedManager.unreadCount(for: list) > 0 {
                        unreadDot
                            .offset(x: 4, y: -4)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if isWiggling, onDelete != nil {
                        deleteBadge
                            .offset(x: -10, y: -10)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

            Text(list.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.middle)
                .wiggleRotation()
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .feedGridCellTap(onTap)
    }

    private var deleteBadge: some View {
        Button {
            onDelete?()
        } label: {
            Color.clear
                .frame(width: 24, height: 24)
                .background(.thinMaterial, in: .circle)
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                .overlay {
                    Circle().strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
                }
                .overlay {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "ListMenu.Delete", table: "Lists"))
    }

    private var unreadDot: some View {
        Circle()
            .fill(.blue.gradient)
            .frame(width: 12, height: 12)
            .overlay {
                Circle().strokeBorder(.blue, lineWidth: 0.5)
            }
    }
}
