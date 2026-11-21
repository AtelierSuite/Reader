import Foundation

nonisolated struct PixivResponse<Body: Decodable & Sendable>: Decodable, Sendable {
    let error: Bool
    let body: Body?

    private enum CodingKeys: String, CodingKey {
        case error, body
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = (try? container.decode(Bool.self, forKey: .error)) ?? false
        body = error ? nil : try container.decode(Body.self, forKey: .body)
    }
}

nonisolated struct PixivDynamicKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

/// pixiv sends an empty JSON array instead of an empty object for keyed collections.
nonisolated struct PixivKeyedCollection<Value: Decodable & Sendable>: Decodable, Sendable {
    let values: [String: Value]

    init(from decoder: Decoder) throws {
        guard let container = try? decoder.container(keyedBy: PixivDynamicKey.self) else {
            values = [:]
            return
        }
        var values: [String: Value] = [:]
        for key in container.allKeys {
            if let value = try? container.decode(Value.self, forKey: key) {
                values[key.stringValue] = value
            }
        }
        self.values = values
    }
}

/// The ID maps in `/profile/all` have `null` values; only the keys matter.
nonisolated struct PixivIDList: Decodable, Sendable {
    let ids: [String]

    init(from decoder: Decoder) throws {
        guard let container = try? decoder.container(keyedBy: PixivDynamicKey.self) else {
            ids = []
            return
        }
        ids = container.allKeys.map(\.stringValue)
    }

    static func newestFirst(_ ids: [String]) -> [String] {
        ids.sorted { (Int($0) ?? 0) > (Int($1) ?? 0) }
    }
}
