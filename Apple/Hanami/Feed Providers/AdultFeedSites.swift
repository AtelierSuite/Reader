import Foundation

public nonisolated enum AdultFeedSites {

    public static func site(forFeedURL feedURL: String) -> AdultSite? {
        if DMMProvider.isAdultFeedURL(feedURL) { return .fanza }
        return nil
    }
}
