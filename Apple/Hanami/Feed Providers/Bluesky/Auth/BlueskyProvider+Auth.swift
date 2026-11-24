import Foundation

public extension BlueskyProvider {

    nonisolated static func hasSession() -> Bool {
        BlueskySessionStore.shared.load() != nil
    }

    nonisolated static func currentSession() -> BlueskySession? {
        BlueskySessionStore.shared.load()
    }

    nonisolated static var signedInHandle: String? {
        BlueskySessionStore.shared.load()?.handle
    }

    nonisolated static func signIn(identifier: String, appPassword: String) async throws -> BlueskySession {
        try await BlueskySessionCoordinator.shared.signIn(identifier: identifier, appPassword: appPassword)
    }

    nonisolated static func clearSession() async {
        await BlueskySessionCoordinator.shared.clearSession()
    }
}
