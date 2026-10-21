import SwiftUI

extension EnvironmentValues {
    /// Set by the compact address capsule while the page's accessory fills it,
    /// so the accessory swaps to its full-width controls in the same pass the
    /// capsule drops its location label.
    @Entry var browserOmniboxTakesOver = false
}

private struct BrowserOmniboxTakeoverModifier: ViewModifier {

    @Environment(\.browserPageSlotReporter) private var slotReporter
    @Environment(\.browserPathToken) private var pathToken
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .onAppear { slotReporter?(.omniboxTakeover(isActive), pathToken) }
            .onChange(of: isActive) { slotReporter?(.omniboxTakeover(isActive), pathToken) }
    }
}

extension View {
    /// Hands the compact address capsule over to this page's omnibox
    /// accessory while active, in place of the page's location.
    func browserOmniboxTakeover(_ isActive: Bool) -> some View {
        modifier(BrowserOmniboxTakeoverModifier(isActive: isActive))
    }
}
