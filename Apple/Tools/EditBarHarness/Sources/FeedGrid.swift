import SwiftUI

struct FeedGrid: View {

    @Environment(FollowingEditModel.self) private var model

    private let gridColumns = [GridItem(.adaptive(minimum: 80), spacing: 16)]

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 20) {
            ForEach(model.feeds) { feed in
                FeedCell(feed: feed)
                    .onTapGesture { tap(feed) }
            }
        }
        .animation(.smooth.speed(2.0), value: model.feeds)
    }

    private func tap(_ feed: HarnessFeed) {
        switch model.mode {
        case .browsing, .editing: model.feedBeingEdited = feed
        case .selecting: model.toggleSelection(feed)
        }
    }
}

private struct FeedCell: View {

    @Environment(FollowingEditModel.self) private var model
    let feed: HarnessFeed

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 16)
                .fill(feed.color)
                .overlay {
                    Image(systemName: feed.symbolName)
                        .font(.title)
                        .foregroundStyle(.white)
                }
                .frame(width: 64, height: 64)
                .overlay(alignment: .topLeading) { deleteBadge }
                .overlay(alignment: .bottomTrailing) { selectionBadge }
                .modifier(WiggleModifier(isActive: model.isEditing, seed: feed.id))
            Text(feed.name)
                .font(.caption)
                .lineLimit(1)
        }
        .contentShape(.rect)
    }

    @ViewBuilder
    private var deleteBadge: some View {
        if model.mode == .editing {
            Button {
                model.delete(feed)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .gray)
            }
            .buttonStyle(.plain)
            .offset(x: -8, y: -8)
            .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var selectionBadge: some View {
        if model.mode == .selecting {
            let isSelected = model.selectedIDs.contains(feed.id)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, isSelected ? Color.accentColor : .black.opacity(0.3))
                .background(Circle().fill(isSelected ? .white : .clear).padding(3))
                .offset(x: 6, y: 6)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

private struct WiggleModifier: ViewModifier {

    let isActive: Bool
    let seed: Int
    @State private var isTilted = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isActive ? (isTilted ? 2 : -2) : 0))
            .animation(
                isActive
                    ? .easeInOut(duration: 0.12 + Double(seed % 4) * 0.01).repeatForever(autoreverses: true)
                    : .smooth,
                value: isTilted
            )
            .onChange(of: isActive, initial: true) { _, isActive in
                isTilted = isActive
            }
    }
}
