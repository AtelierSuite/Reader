import Foundation

public nonisolated enum BlueskyAPIError: Error, Sendable {
    case authenticationRequired
    case requestFailed(status: Int, message: String?)
}
