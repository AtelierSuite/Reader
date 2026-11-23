import Foundation

actor BlueskySessionCoordinator {

    static let shared = BlueskySessionCoordinator()

    private let store: BlueskySessionStore
    private var activeRefreshTask: Task<BlueskySession, Error>?

    init(store: BlueskySessionStore = .shared) {
        self.store = store
    }

    func signIn(identifier: String, appPassword: String) async throws -> BlueskySession {
        let cleanedIdentifier = BlueskyPDSResolver.normalizedIdentifier(identifier)
        let cleanedPassword = appPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedIdentifier.isEmpty, !cleanedPassword.isEmpty else {
            throw BlueskyAuthError.invalidCredentials
        }

        let resolvedEndpoint = await BlueskyPDSResolver.resolvePDSEndpoint(forIdentifier: cleanedIdentifier)
        guard let url = URL(string: "\(resolvedEndpoint)/xrpc/com.atproto.server.createSession") else {
            throw BlueskyAuthError.networkError
        }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "identifier": cleanedIdentifier,
            "password": cleanedPassword
        ])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BlueskyAuthError.networkError
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard status == 200, let root else {
            throw mapAuthError(status: status, root: root)
        }

        let session = try parseSession(from: root, fallbackEndpoint: resolvedEndpoint)
        store.save(session)
        await BlueskyPreferencesCache.shared.invalidate()
        await MainActor.run {
            ProviderSessionEvents.sessionEstablished(.bluesky)
        }
        return session
    }

    func validSession() async -> BlueskySession? {
        guard let session = store.load() else { return nil }
        if let expiration = session.accessTokenExpirationDate,
           expiration.timeIntervalSinceNow < 60 {
            if let refreshed = try? await refreshSession() {
                return refreshed
            }
        }
        return session
    }

    func refreshSession() async throws -> BlueskySession {
        if let existingTask = activeRefreshTask {
            return try await existingTask.value
        }

        let refreshTask = Task<BlueskySession, Error> {
            try await self.performRefresh()
        }
        activeRefreshTask = refreshTask
        defer { activeRefreshTask = nil }
        return try await refreshTask.value
    }

    func clearSession() async {
        activeRefreshTask?.cancel()
        activeRefreshTask = nil
        let existingSession = store.load()
        store.clear()
        await BlueskyPreferencesCache.shared.invalidate()

        if let existingSession,
           let url = URL(string: "\(existingSession.pdsEndpoint)/xrpc/com.atproto.server.deleteSession") {
            var request = URLRequest(url: url, timeoutInterval: 5)
            request.httpMethod = "POST"
            request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("Bearer \(existingSession.refreshJwt)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    private func performRefresh() async throws -> BlueskySession {
        guard let currentSession = store.load() else {
            throw BlueskyAPIError.authenticationRequired
        }
        guard let url = URL(string: "\(currentSession.pdsEndpoint)/xrpc/com.atproto.server.refreshSession") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(currentSession.refreshJwt)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if status == 200, let root {
            let updatedSession = try parseSession(from: root, fallbackEndpoint: currentSession.pdsEndpoint)
            store.save(updatedSession)
            return updatedSession
        }

        let errorCode = root?["error"] as? String
        if status == 400 || status == 401,
           errorCode == "ExpiredToken" || errorCode == "InvalidToken" {
            store.clear()
            await BlueskyPreferencesCache.shared.invalidate()
            throw BlueskyAPIError.authenticationRequired
        }
        throw BlueskyAPIError.requestFailed(status: status, message: root?["message"] as? String)
    }

    private func parseSession(from root: [String: Any], fallbackEndpoint: String) throws -> BlueskySession {
        guard let did = root["did"] as? String, !did.isEmpty,
              let handle = root["handle"] as? String, !handle.isEmpty,
              let accessJwt = root["accessJwt"] as? String, !accessJwt.isEmpty,
              let refreshJwt = root["refreshJwt"] as? String, !refreshJwt.isEmpty else {
            throw BlueskyAuthError.serverError("Invalid session response")
        }
        let pdsEndpoint = BlueskyPDSResolver.extractPDSEndpoint(from: root["didDoc"] as? [String: Any])
            ?? fallbackEndpoint
        return BlueskySession(
            did: did,
            handle: handle,
            accessJwt: accessJwt,
            refreshJwt: refreshJwt,
            pdsEndpoint: pdsEndpoint
        )
    }

    private func mapAuthError(status: Int, root: [String: Any]?) -> BlueskyAuthError {
        let errorCode = root?["error"] as? String
        let message = root?["message"] as? String
        if errorCode == "AuthFactorTokenRequired" {
            return .twoFactorRequired
        }
        if errorCode == "AccountTakedown" || errorCode == "AccountDeactivated" {
            return .accountUnavailable
        }
        if status == 401 || errorCode == "AuthenticationRequired" {
            return .invalidCredentials
        }
        if let message, !message.isEmpty {
            return .serverError(message)
        }
        return .invalidCredentials
    }
}
