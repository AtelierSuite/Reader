import Foundation

public nonisolated struct BlueskySession: Codable, Sendable, Equatable {
    public let did: String
    public let handle: String
    public let accessJwt: String
    public let refreshJwt: String
    public let pdsEndpoint: String

    public init(
        did: String,
        handle: String,
        accessJwt: String,
        refreshJwt: String,
        pdsEndpoint: String
    ) {
        self.did = did
        self.handle = handle
        self.accessJwt = accessJwt
        self.refreshJwt = refreshJwt
        self.pdsEndpoint = pdsEndpoint
    }

    var accessTokenExpirationDate: Date? {
        let segments = accessJwt.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        guard let payloadData = Self.decodeBase64URL(String(segments[1])),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let expiration = payload["exp"] as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: expiration)
    }

    private static func decodeBase64URL(_ encoded: String) -> Data? {
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
