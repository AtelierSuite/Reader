import SwiftUI
import Hanami

struct BrowserTodayQuickAccessIcon: View {
    let symbolName: String
    var section: FeedSection?
    var size: CGFloat = 56

    private var cornerRadius: CGFloat {
        size * 12 / 56
    }

    private var symbol: Image {
        if let providerSymbolName = section?.providerSymbolName {
            Image(providerSymbolName)
        } else {
            Image(systemName: symbolName)
        }
    }

    var body: some View {
        symbol
            .font(.system(size: size * 24 / 56))
            .foregroundStyle(.tint)
            .frame(width: size, height: size)
            .quickAccessFlatTile(cornerRadius: cornerRadius)
    }
}
