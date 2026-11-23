import Foundation

public nonisolated enum BlueskyAuthError: Error, LocalizedError, Sendable {
    case invalidCredentials
    case twoFactorRequired
    case accountUnavailable
    case serverError(String)
    case networkError

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            String(localized: "Bluesky.Error.InvalidCredentials", table: "Integrations")
        case .twoFactorRequired:
            String(localized: "Bluesky.Error.TwoFactorRequired", table: "Integrations")
        case .accountUnavailable:
            String(localized: "Bluesky.Error.AccountUnavailable", table: "Integrations")
        case .serverError(let message):
            message
        case .networkError:
            String(localized: "Bluesky.Error.Network", table: "Integrations")
        }
    }
}
