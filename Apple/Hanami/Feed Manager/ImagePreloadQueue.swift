import Foundation

/// Preloads images outside the refresh queues so a feed counts as refreshed
/// as soon as its content is saved, instead of holding its slot until every
/// image has downloaded.
public nonisolated final class ImagePreloadQueue: @unchecked Sendable {

    public static let shared = ImagePreloadQueue()

    private let lock = NSLock()
    private var pendingURLs: [String] = []
    private var drainTask: Task<Void, Never>?
    private var drainGeneration = 0

    private init() {}

    func enqueue(_ urls: [String]) {
        guard !urls.isEmpty else { return }
        lock.withLock {
            pendingURLs.append(contentsOf: urls)
            if drainTask == nil {
                drainGeneration += 1
                drainTask = makeDrainTask(generation: drainGeneration)
            }
        }
    }

    public func cancelAll() {
        let task = lock.withLock { () -> Task<Void, Never>? in
            let task = drainTask
            pendingURLs.removeAll()
            drainTask = nil
            drainGeneration += 1
            return task
        }
        task?.cancel()
    }

    /// Cancelling the waiting task also cancels the queued preloads.
    func waitUntilIdle() async {
        await withTaskCancellationHandler {
            while !Task.isCancelled, let task = lock.withLock({ drainTask }) {
                await task.value
            }
        } onCancel: {
            cancelAll()
        }
    }

    private func makeDrainTask(generation: Int) -> Task<Void, Never> {
        Task.detached(priority: .utility) {
            try? await withBackgroundActivity(reason: "Image preload") {
                while !Task.isCancelled, let batch = self.takePendingURLs(generation: generation) {
                    await FeedManager.preloadImages(urls: batch)
                }
            }
            self.finishDrain(generation: generation)
        }
    }

    private func takePendingURLs(generation: Int) -> [String]? {
        lock.withLock {
            guard generation == drainGeneration, !pendingURLs.isEmpty else { return nil }
            let batch = pendingURLs
            pendingURLs.removeAll()
            return batch
        }
    }

    /// URLs can arrive after the last batch was taken but before the drain
    /// ends, so those start a new drain instead of waiting for the next enqueue.
    private func finishDrain(generation: Int) {
        lock.withLock {
            guard generation == drainGeneration else { return }
            if pendingURLs.isEmpty || Task.isCancelled {
                drainTask = nil
            } else {
                drainGeneration += 1
                drainTask = makeDrainTask(generation: drainGeneration)
            }
        }
    }
}
