import SwiftUI
import Hanami

struct iPadArticleSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<Article?>? = nil
}

extension EnvironmentValues {
    var iPadArticleSelection: Binding<Article?>? {
        get { self[iPadArticleSelectionKey.self] }
        set { self[iPadArticleSelectionKey.self] = newValue }
    }
}
