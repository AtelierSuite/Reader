import Foundation
import WebKit

public extension FeedProviderRegistry {

    static func adultSite(forFeedURL url: String) -> AdultSite? {
        if DLsiteProvider.requiresAdultContentGate(feedURL: url) {
            return .dlsite
        }
        return nil
    }
}

public extension AdultContentGate {

    /// Feeds from stores that aren't adult-only pass straight through.
    static func authorize(
        feedURL: String, presenter: AdultContentGatePresenter?
    ) async -> Result<Void, AdultContentGateError> {
        guard let site = FeedProviderRegistry.adultSite(forFeedURL: feedURL) else { return .success(()) }
        guard let presenter else { return .failure(.unavailable) }
        return await authorize(site, in: .default(), presenter: presenter)
    }
}

public extension AdultContentGateError {

    var localizedMessage: String {
        switch self {
        case .underage: String(localized: "AdultContentGate.Underage", table: "Feeds")
        case .declined: String(localized: "AdultContentGate.Declined", table: "Feeds")
        case .unavailable: String(localized: "AdultContentGate.Unavailable", table: "Feeds")
        }
    }
}
