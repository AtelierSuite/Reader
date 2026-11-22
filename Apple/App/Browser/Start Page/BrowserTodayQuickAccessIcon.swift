import SwiftUI
import Hanami

struct BrowserTodayQuickAccessIcon: View {
    let symbolName: String
    var section: FeedSection?
    var size: CGFloat = 56
    @State private var icon: UIImage?

    private var cornerRadius: CGFloat {
        size * 12 / 56
    }

    var body: some View {
        iconImage
            .task(id: section) {
                guard let section else { return }
                icon = await Iconography.shared.icon(for: section)
            }
    }

    @ViewBuilder
    private var iconImage: some View {
        if let icon {
            Image(uiImage: icon)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .quickAccessFlatTile(cornerRadius: cornerRadius)
        } else {
            Image(systemName: symbolName)
                .font(.system(size: size * 24 / 56))
                .foregroundStyle(.tint)
                .frame(width: size, height: size)
                .quickAccessFlatTile(cornerRadius: cornerRadius)
        }
    }
}
