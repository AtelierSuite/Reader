import EnhancedNavigation
import Observation
import SwiftUI

/// The progress each tab's visible page has handed the address bar, and
/// whether its omnibox accessory should fill the capsule. Controls go through
/// `tabOmniboxAccessory`; these stay here because they are data the bar
/// draws itself, not controls.
@Observable
final class BrowserPageSlots {

    private(set) var pageProgress: [UUID: BrowserPageSlot<BrowserAddressProgress>] = [:]
    private(set) var pageOmniboxTakeovers: [UUID: BrowserPageSlot<Bool>] = [:]

    func setSlot(_ report: BrowserPageSlotReport, token: BrowserPathToken?, for tabID: UUID) {
        switch report {
        case .progress(let progress):
            BrowserPageSlot.fill(&pageProgress[tabID], with: progress, from: token)
        case .omniboxTakeover(let isActive):
            BrowserPageSlot.fill(&pageOmniboxTakeovers[tabID], with: isActive ? true : nil, from: token)
        }
    }

    func discard(_ tabIDs: [UUID]) {
        for tabID in tabIDs {
            pageProgress[tabID] = nil
            pageOmniboxTakeovers[tabID] = nil
        }
    }

    /// The visible page's own progress, and nothing while a page deeper in
    /// the stack is the one working.
    func displayedProgress(for tabID: UUID, in store: BrowserTabStore) -> BrowserAddressProgress? {
        pageProgress[tabID]?.value(forPageAt: store.displayedPathToken(for: tabID))
    }

    func displayedOmniboxTakeover(for tabID: UUID, in store: BrowserTabStore) -> Bool {
        pageOmniboxTakeovers[tabID]?.value(forPageAt: store.displayedPathToken(for: tabID)) ?? false
    }
}
