import Hanami
import SwiftUI

struct TodayQuickAccessTile: View {

    let title: String
    let symbolName: String
    var section: FeedSection?
    @State private var isHoveringIcon = false
    @State private var isHoveringTitle = false

    private let iconSize: CGFloat = 52
    private let cornerRadius: CGFloat = 12

    var body: some View {
        // No content shape on the stack: clicks and hovers land only on the
        // icon's rounded rect and the title, not the gap or cell around them.
        VStack(spacing: 6) {
            iconView
                .frame(width: iconSize, height: iconSize)
                .clipShape(.rect(cornerRadius: cornerRadius))
                .contentShape(.rect(cornerRadius: cornerRadius))
                .onHover { isHoveringIcon = $0 }
            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 96)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(.rect)
                .onHover { isHoveringTitle = $0 }
        }
        .brightness(isHoveringIcon || isHoveringTitle ? 0.08 : 0)
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

    private var iconView: some View {
        Group {
            if section?.usesMulticolorProviderSymbol == true {
                symbol
                    .resizable()
                    .scaledToFit()
                    .frame(width: 31, height: 31)
                    .offset(x: 1)
            } else {
                symbol
                    .font(.system(size: 26))
                    .foregroundStyle(primaryStyle, section?.providerStyle == nil ? primaryStyle : AnyShapeStyle(.white))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(section?.providerTileTint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.quinary))
    }
}
