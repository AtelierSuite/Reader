import Foundation

nonisolated enum BlueskyPDSResolver {

    static let defaultPDSEndpoint = "https://bsky.social"

    static func resolvePDSEndpoint(forIdentifier identifier: String) async -> String {
        let cleaned = normalizedIdentifier(identifier)
        guard !cleaned.isEmpty, !cleaned.contains("@") else {
            return defaultPDSEndpoint
        }
        let resolvedDID: String?
        if let directDID = cleaned.asDIDIfValid {
            resolvedDID = directDID
        } else {
            resolvedDID = await BlueskyProvider.resolveDID(forHandle: cleaned)
        }
        guard let did = resolvedDID else {
            return defaultPDSEndpoint
        }
        guard let didDocument = await fetchDIDDocument(for: did),
              let endpoint = extractPDSEndpoint(from: didDocument) else {
            return defaultPDSEndpoint
        }
        return endpoint
    }

    static func normalizedIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    static func extractPDSEndpoint(from didDocument: [String: Any]?) -> String? {
        guard let services = didDocument?["service"] as? [[String: Any]] else { return nil }
        for service in services {
            let serviceID = service["id"] as? String
            let serviceType = service["type"] as? String
            guard serviceID == "#atproto_pds" || serviceType == "AtprotoPersonalDataServer",
                  let endpoint = service["serviceEndpoint"] as? String,
                  let normalized = normalizedHTTPSOrigin(endpoint) else {
                continue
            }
            return normalized
        }
        return nil
    }

    private static func fetchDIDDocument(for did: String) async -> [String: Any]? {
        let documentURL: URL?
        if did.hasPrefix("did:plc:") {
            documentURL = URL(string: "https://plc.directory/\(did)")
        } else if did.hasPrefix("did:web:") {
            let domain = String(did.dropFirst("did:web:".count))
            documentURL = domain.isEmpty ? nil : URL(string: "https://\(domain)/.well-known/did.json")
        } else {
            documentURL = nil
        }
        guard let url = documentURL else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            log("BlueskyAuth", "DID document fetch failed for \(did) - \(error.localizedDescription)")
            return nil
        }
    }

    private static func normalizedHTTPSOrigin(_ rawEndpoint: String) -> String? {
        guard let url = URL(string: rawEndpoint),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            return nil
        }
        return rawEndpoint.hasSuffix("/") ? String(rawEndpoint.dropLast()) : rawEndpoint
    }
}
