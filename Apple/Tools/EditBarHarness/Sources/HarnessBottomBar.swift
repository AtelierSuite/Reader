import SwiftUI

/// Stands in for `BrowserBottomBar`: Back, the address capsule and Tabs,
/// with whichever edit controls the selected variant puts around them.
struct HarnessBottomBar: View {

    @Environment(FollowingEditModel.self) private var model
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: BarMetrics.itemSpacing) {
            HStack(spacing: BarMetrics.itemSpacing) {
                if model.showsNavigationButtons {
                    BarCircleButton(title: "Back", systemImage: "chevron.backward", isEnabled: false) {}
                        .glassEffectID("back", in: glassNamespace)
                }
                capsule
                    .glassEffectID("address", in: glassNamespace)
                if model.variant == .fanOut {
                    FanOutCircles(glassNamespace: glassNamespace)
                }
                if model.showsNavigationButtons {
                    BarCircleButton(title: "Tabs", systemImage: "square.on.square") {}
                        .glassEffectID("tabs", in: glassNamespace)
                }
            }
        }
        .foregroundStyle(.primary)
        .imageScale(.large)
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var capsule: some View {
        Group {
            switch model.variant {
            case .takeover: TakeoverCapsuleContent()
            case .fanOut: FanOutCapsuleContent()
            case .menu: MenuCapsuleContent()
            }
        }
        .frame(maxWidth: .infinity, minHeight: BarMetrics.itemHeight)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

enum BarMetrics {
    static let itemHeight: CGFloat = 48
    static let itemSpacing: CGFloat = 10
    static let contentInset: CGFloat = 17
}

struct BarCircleButton: View {

    let title: String
    let systemImage: String
    var isProminent = false
    var isDestructive = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: isProminent ? .semibold : .medium))
                .foregroundStyle(foregroundStyle)
                .frame(width: BarMetrics.itemHeight, height: BarMetrics.itemHeight)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .glassEffect(isProminent ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: .circle)
        .accessibilityLabel(title)
    }

    private var foregroundStyle: AnyShapeStyle {
        if isProminent { return AnyShapeStyle(.white) }
        guard isEnabled else { return AnyShapeStyle(.tertiary) }
        return isDestructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary)
    }
}

struct FollowingLocationLabel: View {

    @Environment(FollowingEditModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.blue)
                .overlay {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text("Following")
                    .font(.subheadline.weight(.semibold))
                Text("\(model.feeds.count) feeds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AddFeedMenu: View {

    @Environment(FollowingEditModel.self) private var model

    var body: some View {
        Menu {
            Button("Add Feed", systemImage: "plus") { model.addFeed() }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 36, height: BarMetrics.itemHeight)
                .contentShape(.rect)
        }
        .accessibilityLabel("More")
    }
}
