import SwiftUI

struct ScrollExpandedToolbar: View {

    static let buttonSize: CGFloat = 44

    let isRefreshing: Bool
    let onBack: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            toolbarButton(systemImage: "chevron.down", action: onBack)
                .accessibilityLabel(String(localized: "Scroll.Back", table: "Articles"))

            Spacer(minLength: 0)

            toolbarButton(systemImage: "arrow.clockwise", action: onRefresh)
                .disabled(isRefreshing)
                .accessibilityLabel(String(localized: "Scroll.Refresh", table: "Articles"))
        }
        .padding(.horizontal, 16)
    }

    private func toolbarButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .imageScale(.large)
                .foregroundStyle(.white)
                .frame(width: Self.buttonSize, height: Self.buttonSize)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .compatibleGlassEffect(in: .circle, interactive: true)
    }
}
