import SwiftUI

struct ScrollExpandedToolbar: View {

    static let buttonSize: CGFloat = 36

    let isRefreshing: Bool
    let onBack: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: Self.buttonSize, height: Self.buttonSize)
            }
            .compatibleGlassButtonStyle()
            .buttonBorderShape(.circle)
            .accessibilityLabel(String(localized: "Scroll.Back", table: "Articles"))

            Spacer(minLength: 0)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.body.weight(.semibold))
                    .frame(width: Self.buttonSize, height: Self.buttonSize)
            }
            .compatibleGlassButtonStyle()
            .buttonBorderShape(.circle)
            .disabled(isRefreshing)
            .accessibilityLabel(String(localized: "Scroll.Refresh", table: "Articles"))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
    }
}
