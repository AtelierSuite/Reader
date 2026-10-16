import SwiftUI

extension View {

    func sheetLayout() -> some View {
        #if os(macOS)
        formStyle(.grouped)
            .frame(minWidth: 560, minHeight: 560)
        #else
        self
        #endif
    }
}
