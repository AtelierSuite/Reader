import Foundation

public nonisolated enum DLsiteShop: String, Sendable, CaseIterable {
    case home
    case soft
    case app
    case girlsDrama = "girls-drama"
    case blDrama = "bl-drama"
    case maniax
    case books
    case pro
    case aix
    case girls
    case bl
    case girlsPro = "girls-pro"
    case blPro = "bl-pro"

    public enum Rating: Sendable {
        case allAges
        case adult
        case mixed
    }

    public var rating: Rating {
        switch self {
        case .home, .soft, .app, .girlsDrama, .blDrama: .allAges
        case .maniax, .books, .pro, .aix: .adult
        case .girls, .bl, .girlsPro, .blPro: .mixed
        }
    }

    public var requiresAdultContentGate: Bool {
        rating != .allAges
    }

    public init?(pathSegment: String) {
        var name = pathSegment.lowercased()
        if name.hasSuffix("-touch") {
            name = String(name.dropLast("-touch".count))
        }
        if name == "gay" {
            name = DLsiteShop.bl.rawValue
        }
        self.init(rawValue: name)
    }
}
