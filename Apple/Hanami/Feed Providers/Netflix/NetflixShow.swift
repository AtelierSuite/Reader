import Foundation

/// Seasons and episodes are kept oldest first; long-running shows list them newest first, paged.
nonisolated struct NetflixShow: Sendable {
    let showID: String
    let title: String
    let synopsis: String?
    let artworkURL: String?
    let tagline: String?
    let seasons: [NetflixSeason]

    init?(video: [String: Any]) {
        guard video["__typename"] as? String == "Show",
              let showID = NetflixPageData.identifier(video["videoId"]),
              let title = NetflixPageData.text(video["title"]) else { return nil }
        self.showID = showID
        self.title = title
        synopsis = NetflixPageData.text(video["shortSynopsis"])
        artworkURL = NetflixPageData.imageURL(video["billboardOrStoryArt960"])
            ?? NetflixPageData.imageURL(video["billboardOrStoryArt1280"])
        tagline = (video["taglineMessages"] as? [[String: Any]])?
            .lazy.compactMap { NetflixPageData.text($0["tagline"]) }.first
        let listedSeasons = NetflixPageData.edgeNodes(video["seasons"]).compactMap(NetflixSeason.init(node:))
        seasons = listedSeasons.contains(where: \.isListedNewestFirst) ? listedSeasons.reversed() : listedSeasons
    }
}

nonisolated struct NetflixSeason: Sendable {
    let seasonID: String
    let label: String?
    let episodes: [NetflixEpisode]
    let isListedNewestFirst: Bool

    init?(node: [String: Any]) {
        guard let seasonID = NetflixPageData.identifier(node["videoId"]) else { return nil }
        self.seasonID = seasonID
        label = NetflixPageData.text(node["numberLabelV2"]) ?? NetflixPageData.text(node["title"])
        let listedEpisodes = NetflixPageData.edgeNodes(node["episodes"]).compactMap(NetflixEpisode.init(node:))
        let numbers = listedEpisodes.compactMap(\.number)
        isListedNewestFirst = (numbers.first ?? 0) > (numbers.last ?? 0)
        episodes = isListedNewestFirst ? listedEpisodes.reversed() : listedEpisodes
    }
}

nonisolated struct NetflixEpisode: Sendable {
    let episodeID: String
    let number: Int?
    let title: String?
    let synopsis: String?
    let runtimeSeconds: Int?
    let stillURL: String?

    init?(node: [String: Any]) {
        guard let episodeID = NetflixPageData.identifier(node["videoId"]) else { return nil }
        self.episodeID = episodeID
        number = (node["number"] as? NSNumber)?.intValue
        title = NetflixPageData.text(node["title"])
        synopsis = NetflixPageData.text(node["shortSynopsis"])
        runtimeSeconds = (node["runtimeSec"] as? NSNumber)?.intValue
        stillURL = NetflixPageData.imageURL(node["merchStill300"])
    }
}
