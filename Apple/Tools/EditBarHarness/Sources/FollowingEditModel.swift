import SwiftUI

struct HarnessFeed: Identifiable, Hashable {
    let id: Int
    let name: String
    let symbolName: String
    let color: Color

    static let samples: [HarnessFeed] = [
        ("The Verge", "bolt.fill", Color.purple),
        ("Daring Fireball", "star.fill", .gray),
        ("Six Colors", "paintpalette.fill", .orange),
        ("MacStories", "m.circle.fill", .red),
        ("Ars Technica", "atom", .orange),
        ("Swift Blog", "swift", .orange),
        ("NHK News", "newspaper.fill", .blue),
        ("Kotaku", "gamecontroller.fill", .pink),
        ("Hacker News", "y.circle.fill", .orange),
        ("Stratechery", "chart.line.uptrend.xyaxis", .teal),
        ("Pixel Envy", "camera.fill", .indigo),
        ("Accidental Tech", "mic.fill", .green),
        ("NASA", "moon.stars.fill", .blue),
        ("Polygon", "triangle.fill", .pink),
        ("WWDC Notes", "apple.logo", .gray),
        ("Cooking", "fork.knife", .brown)
    ].enumerated().map { index, sample in
        HarnessFeed(id: index, name: sample.0, symbolName: sample.1, color: sample.2)
    }
}

enum BarVariant: String, CaseIterable, Identifiable {
    case takeover = "Capsule"
    case fanOut = "Circles"
    case menu = "Menu (Today)"

    var id: String { rawValue }
}

@MainActor
@Observable
final class FollowingEditModel {

    enum Mode {
        case browsing, editing, selecting
    }

    var mode: Mode = .browsing
    var feeds: [HarnessFeed] = HarnessFeed.samples
    var selectedIDs: Set<Int> = []
    var variant: BarVariant = .takeover
    var collapsesNavigationWhileEditing = true
    var feedBeingEdited: HarnessFeed?
    var isPresentingBulkEdit = false
    var isPresentingBulkDelete = false
    private var nextFeedID = HarnessFeed.samples.count

    var isEditing: Bool { mode != .browsing }

    var showsNavigationButtons: Bool {
        !(isEditing && collapsesNavigationWhileEditing)
    }

    func beginEditing() {
        withAnimation(Self.barAnimation) { mode = .editing }
    }

    func toggleSelectMode() {
        withAnimation(Self.barAnimation) {
            if mode == .selecting {
                mode = .editing
                selectedIDs = []
            } else {
                mode = .selecting
            }
        }
    }

    func endEditing() {
        withAnimation(Self.barAnimation) {
            mode = .browsing
            selectedIDs = []
        }
    }

    func toggleSelection(_ feed: HarnessFeed) {
        withAnimation(.smooth.speed(2.0)) {
            if selectedIDs.contains(feed.id) {
                selectedIDs.remove(feed.id)
            } else {
                selectedIDs.insert(feed.id)
            }
        }
    }

    func delete(_ feed: HarnessFeed) {
        withAnimation(.smooth.speed(2.0)) {
            feeds.removeAll { $0.id == feed.id }
            if feeds.isEmpty { mode = .browsing }
        }
    }

    func deleteSelected() {
        withAnimation(Self.barAnimation) {
            feeds.removeAll { selectedIDs.contains($0.id) }
            selectedIDs = []
            mode = feeds.isEmpty ? .browsing : .editing
        }
    }

    func addFeed() {
        withAnimation(.smooth.speed(2.0)) {
            feeds.append(HarnessFeed(
                id: nextFeedID,
                name: "New Feed \(nextFeedID)",
                symbolName: "dot.radiowaves.up.forward",
                color: .mint
            ))
            nextFeedID += 1
        }
    }

    static let barAnimation = Animation.smooth(duration: 0.4)
}
