import SwiftUI

private struct QuickAccessFlatTileModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        content
            .background {
                if let tint {
                    shape.fill(tint)
                } else {
                    shape.fill(.fill.tertiary)
                }
            }
            .clipShape(shape)
            .wiggleRotation()
    }
}

extension View {
    func quickAccessFlatTile(cornerRadius: CGFloat, tint: Color? = nil) -> some View {
        modifier(QuickAccessFlatTileModifier(cornerRadius: cornerRadius, tint: tint))
    }
}
