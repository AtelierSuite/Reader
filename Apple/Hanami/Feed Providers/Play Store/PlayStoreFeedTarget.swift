import Foundation

public nonisolated struct PlayStoreFeedTarget: Sendable, Equatable {

    public enum Kind: String, Sendable {
        case app
        case developerNumeric
        case developerNamed
    }

    public let kind: Kind
    public let country: String
    public let identifier: String

    public var isDeveloper: Bool {
        kind == .developerNumeric || kind == .developerNamed
    }

    public var feedURL: String {
        let encodedIdentifier = identifier.addingPercentEncoding(withAllowedCharacters: .playStorePathSegment)
            ?? identifier
        switch kind {
        case .app:
            return "\(PlayStoreProvider.appScheme)://\(country)/\(encodedIdentifier)"
        case .developerNumeric:
            return "\(PlayStoreProvider.developerScheme)://\(country)/dev/\(encodedIdentifier)"
        case .developerNamed:
            return "\(PlayStoreProvider.developerScheme)://\(country)/developer/\(encodedIdentifier)"
        }
    }

    public var siteURL: String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "play.google.com"
        switch kind {
        case .app:
            components.path = "/store/apps/details"
        case .developerNumeric:
            components.path = "/store/apps/dev"
        case .developerNamed:
            components.path = "/store/apps/developer"
        }
        components.queryItems = [
            URLQueryItem(name: "id", value: identifier),
            URLQueryItem(name: "gl", value: country.uppercased())
        ]
        return components.string ?? "https://play.google.com"
    }

    public var fetchURL: URL? {
        var components = URLComponents(string: siteURL)
        var items = components?.queryItems ?? []
        items.append(URLQueryItem(name: "hl", value: PlayStoreProvider.defaultLanguage))
        components?.queryItems = items
        return components?.url
    }

    public init(kind: Kind, country: String, identifier: String) {
        self.kind = kind
        self.country = country.lowercased()
        self.identifier = identifier
    }

    public init?(feedURL: String) {
        guard let components = URLComponents(string: feedURL),
              let country = components.host?.lowercased(),
              country.count == 2, country.allSatisfy(\.isLetter) else { return nil }
        let pathSegments = components.path.split(separator: "/", maxSplits: 1).map(String.init)
        switch components.scheme {
        case PlayStoreProvider.appScheme:
            guard pathSegments.count == 1, Self.isValidPackageIdentifier(pathSegments[0]) else { return nil }
            self.init(kind: .app, country: country, identifier: pathSegments[0])
        case PlayStoreProvider.developerScheme:
            guard pathSegments.count == 2, !pathSegments[1].isEmpty else { return nil }
            switch pathSegments[0] {
            case "dev":
                guard pathSegments[1].allSatisfy(\.isNumber) else { return nil }
                self.init(kind: .developerNumeric, country: country, identifier: pathSegments[1])
            case "developer":
                self.init(kind: .developerNamed, country: country, identifier: pathSegments[1])
            default:
                return nil
            }
        default:
            return nil
        }
    }

    public init?(pageURL: URL) {
        guard let host = pageURL.host?.lowercased(), host == "play.google.com",
              let components = URLComponents(url: pageURL, resolvingAgainstBaseURL: false) else { return nil }
        let queryItems = components.queryItems ?? []
        guard let rawIdentifier = queryItems.first(where: { $0.name == "id" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawIdentifier.isEmpty else { return nil }
        let countryParam = queryItems.first(where: { $0.name.lowercased() == "gl" })?.value?.lowercased()
        let country = countryParam.flatMap { value in
            value.count == 2 && value.allSatisfy(\.isLetter) ? value : nil
        } ?? PlayStoreProvider.defaultCountry

        let normalizedPath = pageURL.path.lowercased()
        if normalizedPath == "/store/apps/details" || normalizedPath.hasSuffix("/store/apps/details") {
            guard Self.isValidPackageIdentifier(rawIdentifier) else { return nil }
            self.init(kind: .app, country: country, identifier: rawIdentifier)
        } else if normalizedPath == "/store/apps/dev" || normalizedPath.hasSuffix("/store/apps/dev") {
            guard rawIdentifier.allSatisfy(\.isNumber) else { return nil }
            self.init(kind: .developerNumeric, country: country, identifier: rawIdentifier)
        } else if normalizedPath == "/store/apps/developer" || normalizedPath.hasSuffix("/store/apps/developer") {
            let decodedName = rawIdentifier.replacingOccurrences(of: "+", with: " ")
            self.init(kind: .developerNamed, country: country, identifier: decodedName)
        } else {
            return nil
        }
    }

    private static func isValidPackageIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.contains(".") && value.allSatisfy { character in
            character.isASCII && (character.isLetter || character.isNumber || character == "." || character == "_")
        }
    }
}

private nonisolated extension CharacterSet {
    static let playStorePathSegment: CharacterSet = {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        return allowed
    }()
}
