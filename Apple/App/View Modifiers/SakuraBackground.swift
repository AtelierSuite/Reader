import SwiftUI
import Hanami

private struct FeedBackgroundColorsKey: EnvironmentKey {
    static let defaultValue: [Color] = []
}

private struct SakuraBackgroundDisabledKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var feedBackgroundColors: [Color] {
        get { self[FeedBackgroundColorsKey.self] }
        set { self[FeedBackgroundColorsKey.self] = newValue }
    }

    var isSakuraBackgroundDisabled: Bool {
        get { self[SakuraBackgroundDisabledKey.self] }
        set { self[SakuraBackgroundDisabledKey.self] = newValue }
    }
}

#if !os(visionOS) && !os(macOS)
struct SakuraBackground: ViewModifier {

    @Environment(\.feedBackgroundColors) private var feedColors
    @Environment(\.isSakuraBackgroundDisabled) private var isDisabled

    private var isActive: Bool { !isDisabled }

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(isActive ? .hidden : .automatic)
            .background(alignment: .top) {
                ZStack(alignment: .top) {
                    if isActive {
                        LinearGradient(
                            colors: [
                                Color("BackgroundGradientTop"),
                                Color("BackgroundGradientBottom")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    if !isDisabled, !feedColors.isEmpty {
                        FeedHeaderGradientView(colors: feedColors)
                            .frame(height: 360)
                    }
                }
                .ignoresSafeArea()
            }
    }
}
#endif

extension View {
    @ViewBuilder
    func sakuraBackground() -> some View {
        #if os(visionOS) || os(macOS)
        self
        #else
        modifier(SakuraBackground())
        #endif
    }
}
