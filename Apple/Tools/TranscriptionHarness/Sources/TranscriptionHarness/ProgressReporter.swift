import Foundation
import Synchronization

nonisolated final class ProgressReporter: Sendable {

    private let label: String
    private let lastPercentage = Mutex(-1)

    init(label: String) {
        self.label = label
    }

    func report(_ fraction: Double) {
        let percentage = Int((min(max(fraction, 0), 1) * 100).rounded(.down))
        let shouldPrint = lastPercentage.withLock { last in
            guard percentage != last else { return false }
            last = percentage
            return true
        }
        guard shouldPrint else { return }
        FileHandle.standardError.write(Data("\r\(label): \(percentage)%".utf8))
    }

    func finish() {
        FileHandle.standardError.write(Data("\n".utf8))
    }
}
