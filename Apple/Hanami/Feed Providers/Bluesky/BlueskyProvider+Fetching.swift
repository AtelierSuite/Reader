import Foundation

public extension BlueskyProvider {

    nonisolated static let publicAPIHost = "public.api.bsky.app"

    func performFetch(handle: String) async -> BlueskyProfileFetchResult {
        let empty = BlueskyProfileFetchResult(profileImageURL: nil, displayName: nil)

        guard let did = await Self.resolveDID(forHandle: handle) ?? handle.asDIDIfValid,
              let profile = await Self.fetchActorProfile(actor: did) else {
            return empty
        }
        return profile
    }

    /// Resolves a Bluesky handle (e.g. `atsumiresearch.bsky.social`) to a DID.
    nonisolated static func resolveDID(forHandle handle: String) async -> String? {
        guard var components = URLComponents(
            string: "https://\(publicAPIHost)/xrpc/com.atproto.identity.resolveHandle"
        ) else { return nil }
        components.queryItems = [URLQueryItem(name: "handle", value: handle)]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let did = root["did"] as? String,
                  !did.isEmpty else { return nil }
            return did
        } catch {
            log("BlueskyProfile", "resolveHandle failed - \(error.localizedDescription)")
            return nil
        }
    }

    nonisolated static func fetchActorProfile(actor: String) async -> BlueskyProfileFetchResult? {
        do {
            let root = try await xrpc(
                "app.bsky.actor.getProfile",
                query: [URLQueryItem(name: "actor", value: actor)]
            )
            let avatar = (root["avatar"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let displayName = (root["displayName"] as? String).flatMap { $0.isEmpty ? nil : $0 }

            return BlueskyProfileFetchResult(
                profileImageURL: avatar,
                displayName: displayName
            )
        } catch {
            log("BlueskyProfile", "getProfile failed - \(error.localizedDescription)")
            return nil
        }
    }
}
