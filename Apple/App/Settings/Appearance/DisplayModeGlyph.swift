import SwiftUI

/// A phone outline sketching each display mode's bottom chrome: the tab bar
/// for Classic, and the back button, address bar and tab count for Browser.
struct DisplayModeGlyph: View {

    let mode: AppDisplayMode

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(lineWidth: 2.5)
            VStack(alignment: .leading, spacing: 5) {
                ForEach([1.0, 0.8, 1.0, 0.6, 0.9], id: \.self) { width in
                    Capsule()
                        .frame(height: 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(x: width, anchor: .leading)
                }
                Spacer(minLength: 0)
            }
            .opacity(0.3)
            .padding(.horizontal, 10)
            .padding(.top, 14)
            chrome
                .padding(.horizontal, 6)
                .padding(.bottom, 7)
        }
        .frame(width: 66, height: 120)
    }

    @ViewBuilder
    private var chrome: some View {
        switch mode {
        case .classic:
            HStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle()
                        .frame(width: 5, height: 5)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 14)
            .background(Capsule().opacity(0.25))
        case .browser:
            HStack(spacing: 3) {
                Circle()
                    .opacity(0.25)
                    .frame(width: 14, height: 14)
                Capsule()
                    .opacity(0.25)
                    .frame(height: 14)
                    .overlay {
                        Capsule()
                            .frame(width: 16, height: 3)
                    }
                Circle()
                    .opacity(0.25)
                    .frame(width: 14, height: 14)
            }
        }
    }
}
