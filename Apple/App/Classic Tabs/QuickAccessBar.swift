import SwiftUI
import Hanami

struct QuickAccessBar: View {

    let tabs: [QuickAccessBarItem]
    @Binding var selection: ClassicHomeSource
    var onEdit: () -> Void

    @State private var tabFrames: [String: CGRect] = [:]
    @State private var hasPerformedInitialScroll = false

    private var indicatorFrame: CGRect {
        tabFrames[selection.token] ?? .zero
    }

    private var indicatorStyle: AnyShapeStyle {
        switch selection {
        case .allContent:
            return AnyShapeStyle(Color.accentColor)
        case .feedSection(let section):
            return homeSection(for: section)?.tabAccentStyle ?? AnyShapeStyle(Color.accentColor)
        case .list:
            let iconName = tabs.first(where: { $0.source == selection })?.listIconName
            if let iconName, let icon = ListIcon(rawValue: iconName) {
                return AnyShapeStyle(icon.gradient)
            }
            return AnyShapeStyle(Color.accentColor)
        }
    }

    private func selectedTextColor(for tab: QuickAccessBarItem) -> Color {
        if case .feedSection(let section) = tab.source, let homeSection = homeSection(for: section) {
            return homeSection.tabSelectedTextColor
        }
        return .white
    }

    private func homeSection(for section: FeedSection) -> HomeSection? {
        HomeSection(rawValue: section.rawValue)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabs) { tab in
                        QuickAccessBarButton(
                            tab: tab,
                            isSelected: tab.source == selection,
                            selectedTextColor: selectedTextColor(for: tab)
                        ) {
                            selection = tab.source
                        }
                        .contextMenu {
                            Button(action: onEdit) {
                                Label(String(localized: "QuickAccessBar.Edit", table: "Home"),
                                      systemImage: "arrow.up.arrow.down")
                            }
                        }
                        .id(tab.id)
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: QuickAccessBarFrameKey.self,
                                    value: [tab.id: geometry.frame(in: .named(Self.coordinateSpaceID))]
                                )
                            }
                        }
                    }
                }
                .padding(4)
                .coordinateSpace(name: Self.coordinateSpaceID)
                .background(alignment: .topLeading) {
                    Capsule()
                        .fill(indicatorStyle)
                        .frame(width: indicatorFrame.width, height: indicatorFrame.height)
                        .offset(x: indicatorFrame.minX, y: indicatorFrame.minY)
                        .opacity(indicatorFrame.width > 0 ? 1 : 0)
                        .animation(.smooth.speed(2.0), value: indicatorFrame)
                }
                .onPreferenceChange(QuickAccessBarFrameKey.self) { newFrames in
                    tabFrames.merge(newFrames, uniquingKeysWith: { _, new in new })
                }
            }
            // Glass sits behind the scroll content rather than wrapping it, so a
            // programmatic scroll repaints instead of leaving a stale composite.
            .background {
                Color.clear.compatibleGlassEffect(in: .capsule, interactive: true)
            }
            .clipShape(.capsule)
            .onChange(of: tabFrames, initial: true) {
                guard !hasPerformedInitialScroll, tabFrames[selection.token] != nil else { return }
                hasPerformedInitialScroll = true
                scrollSelectionIntoView(proxy, animated: false)
            }
            .onChange(of: selection) {
                scrollSelectionIntoView(proxy, animated: true)
            }
            .onChange(of: tabs.map(\.id)) {
                scrollSelectionIntoView(proxy, animated: true)
            }
        }
    }

    private func scrollSelectionIntoView(_ proxy: ScrollViewProxy, animated: Bool) {
        let target = selection.token
        Task { @MainActor in
            if animated {
                withAnimation(.smooth.speed(2.0)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            } else {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    private static let coordinateSpaceID = "QuickAccessBar"
}

private struct QuickAccessBarFrameKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
