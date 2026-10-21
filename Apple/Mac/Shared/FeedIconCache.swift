import AppKit
import Hanami
import Observation

/// Feed icons for list rows, looked up once per feed until icons change.
@Observable
final class FeedIconCache {

    static let shared = FeedIconCache()

    /// Bumped whenever feed icons change, so views showing one reload it.
    private(set) var revision = 0

    @ObservationIgnored private var icons: [Int64: NSImage] = [:]
    @ObservationIgnored private var loading: Set<Int64> = []
    @ObservationIgnored private var waiting: [Int64: [(NSImage?) -> Void]] = [:]
    @ObservationIgnored private var iconObserver: ChangeObserver?

    func observeIconChanges(of feedManager: FeedManager) {
        iconObserver = ChangeObserver {
            _ = feedManager.iconRevision
        } onChange: { [weak self] in
            self?.icons.removeAll()
            self?.revision += 1
        }
    }

    func icon(for feed: Feed, completion: @escaping (NSImage?) -> Void) {
        if let icon = icons[feed.id] {
            completion(icon)
            return
        }
        waiting[feed.id, default: []].append(completion)
        guard loading.insert(feed.id).inserted else { return }
        let requestedRevision = revision
        Task {
            let icon = await Iconography.shared.icon(for: feed)
                ?? InitialsAvatar.renderToImage(name: feed.title, size: 64)
            if requestedRevision == revision {
                icons[feed.id] = icon
            }
            loading.remove(feed.id)
            (waiting.removeValue(forKey: feed.id) ?? []).forEach { $0(icon) }
        }
    }
}
