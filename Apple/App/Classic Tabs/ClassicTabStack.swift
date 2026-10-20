import SwiftUI

struct ClassicTabStack<Root: View>: View {

    @Binding var path: NavigationPath
    @ViewBuilder let root: () -> Root

    var body: some View {
        NavigationStack(path: $path) {
            root()
                .browserNavigationEnvironment(path: $path)
                .browserNavigationDestinations(path: $path)
        }
        .compatibleSoftScrollEdgeEffectStyle()
    }
}
