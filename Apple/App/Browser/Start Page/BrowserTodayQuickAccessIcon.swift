import SwiftUI
import Hanami

struct BrowserTodayQuickAccessIcon: View {
    let symbolName: String
    var section: FeedSection?
    var size: CGFloat = 56

    private var cornerRadius: CGFloat {
        size * 12 / 56
    }

    private var primaryStyle: AnyShapeStyle {
        section?.providerStyle ?? AnyShapeStyle(.tint)
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
            .font(.system(size: size * 28 / 56))
            .foregroundStyle(primaryStyle, section?.providerStyle == nil ? primaryStyle : AnyShapeStyle(.white))
            .frame(width: size, height: size)
            .quickAccessFlatTile(cornerRadius: cornerRadius, tint: section?.providerTileTint)
    }
}
