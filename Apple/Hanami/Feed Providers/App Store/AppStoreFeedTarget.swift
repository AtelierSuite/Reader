import Foundation

public nonisolated struct AppStoreFeedTarget: Sendable, Equatable {

    public enum Kind: String, Sendable {
        case app
        case developer
    }

    public let kind: Kind
    public let storefront: String
    public let identifier: String

    public var feedURL: String {
        let scheme = kind == .app ? AppStoreProvider.appScheme : AppStoreProvider.developerScheme
        return "\(scheme)://\(storefront)/\(identifier)"
    }

    public var siteURL: String {
        "https://apps.apple.com/\(storefront)/\(kind.rawValue)/id\(identifier)"
    }

    public init(kind: Kind, storefront: String, identifier: String) {
        self.kind = kind
        self.storefront = storefront
        self.identifier = identifier
    }

    public init?(feedURL: String) {
        guard let components = URLComponents(string: feedURL),
              let storefront = components.host,
              let identifier = components.path.split(separator: "/").first.map(String.init),
              identifier.allSatisfy(\.isNumber) else { return nil }
        switch components.scheme {
        case AppStoreProvider.appScheme: self.init(kind: .app, storefront: storefront, identifier: identifier)
        case AppStoreProvider.developerScheme:
            self.init(kind: .developer, storefront: storefront, identifier: identifier)
        default: return nil
        }
    }

    public init?(pageURL: URL) {
        guard let host = pageURL.host?.lowercased(),
              host == "apps.apple.com" || host == "itunes.apple.com" else { return nil }
        let segments = pageURL.path.split(separator: "/").map { $0.lowercased() }
        guard let identifier = segments.last(where: { $0.hasPrefix("id") && $0.dropFirst(2).allSatisfy(\.isNumber) })
            .map({ String($0.dropFirst(2)) }), !identifier.isEmpty else { return nil }
        let kind: Kind
        if segments.contains("app") {
            kind = .app
        } else if segments.contains("developer") || segments.contains("artist") {
            kind = .developer
        } else {
            return nil
        }
        let storefront = segments.first.flatMap { $0.count == 2 && $0.allSatisfy(\.isLetter) ? $0 : nil }
        self.init(kind: kind, storefront: storefront ?? AppStoreProvider.defaultStorefront, identifier: identifier)
    }
}
