import SwiftUI

/// A phone outline sketching each display mode's bottom chrome: the tab bar
/// for Classic, and the back button, address bar and tab count for Browser.
/// Sizes are an iPhone screen's points scaled down, so the glyph keeps the
/// device's proportions. Each bar is inset so its rounded ends share a centre
/// with the screen's corners.
struct DisplayModeGlyph: View {

    let mode: AppDisplayMode

    private let scale: CGFloat = 0.15
    private let bezel: CGFloat = 2
    private let rowWidths: [CGFloat] = [0.9, 0.6, 0.8, 0.5, 0.75, 0.55]

    private var screenCornerRadius: CGFloat { 62 * scale }
    private var tabBarHeight: CGFloat { 64 * scale }
    private var toolbarHeight: CGFloat { 50 * scale }

    /// The inset that keeps a capsule of this height concentric with the
    /// screen's corners, measured from the outside of the bezel.
    private func concentricInset(forHeight height: CGFloat) -> CGFloat {
        screenCornerRadius - height / 2 + bezel
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: screenCornerRadius + bezel, style: .continuous)
                .strokeBorder(lineWidth: bezel)
            content
            chrome
        }
        .frame(width: 402 * scale + bezel * 2, height: 874 * scale + bezel * 2)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .frame(width: 180 * scale, height: 24 * scale)
                .padding(.bottom, 28 * scale)
            ForEach(Array(rowWidths.enumerated()), id: \.offset) { _, width in
                Capsule()
                    .frame(width: 362 * scale * width, height: 10 * scale)
                    .padding(.bottom, 22 * scale)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(0.3)
        .padding(.horizontal, 20 * scale + bezel)
        .padding(.top, 104 * scale + bezel)
    }

    @ViewBuilder
    private var chrome: some View {
        switch mode {
        case .classic:
            HStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle()
                        .frame(width: 22 * scale, height: 22 * scale)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: tabBarHeight)
            .background(Capsule().opacity(0.25))
            .padding([.horizontal, .bottom], concentricInset(forHeight: tabBarHeight))
        case .browser:
            HStack(spacing: 10 * scale) {
                Circle()
                    .opacity(0.25)
                    .frame(width: toolbarHeight, height: toolbarHeight)
                Capsule()
                    .opacity(0.25)
                    .frame(height: toolbarHeight)
                    .overlay {
                        Capsule()
                            .frame(width: 100 * scale, height: 12 * scale)
                    }
                Circle()
                    .opacity(0.25)
                    .frame(width: toolbarHeight, height: toolbarHeight)
            }
            .padding([.horizontal, .bottom], concentricInset(forHeight: toolbarHeight))
        }
    }
}
