import Foundation

nonisolated struct NetflixEpisodeItem {

    let show: NetflixShow
    let season: NetflixSeason
    let episode: NetflixEpisode

    var title: String {
        let name = episode.title ?? season.label ?? show.title
        guard let number = episode.number else { return name }
        return "\(number). \(name)"
    }

    var author: String {
        [show.title, season.label].compactMap(\.self).joined(separator: " · ")
    }

    var runtime: String? {
        guard let seconds = episode.runtimeSeconds, seconds > 0 else { return nil }
        return Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    var summary: String? {
        let synopsis = episode.synopsis?.trimmingCharacters(in: .whitespacesAndNewlines)
        return synopsis?.isEmpty == false ? synopsis : nil
    }

    var html: String {
        var blocks: [String] = []
        if let stillURL = episode.stillURL {
            blocks.append("<figure><img src=\"\(RSSParser.escapeXMLAttribute(stillURL))\"></figure>")
        }
        if let summary {
            blocks.append("<p>\(RSSParser.escapeXMLText(summary))</p>")
        }
        if let runtime {
            blocks.append("<p><small>\(RSSParser.escapeXMLText(runtime))</small></p>")
        }
        return blocks.joined()
    }

    func articleItem(publishedDate: Date) -> ArticleInsertItem {
        ArticleInsertItem(
            title: title,
            url: NetflixProvider.watchURL(for: episode.episodeID),
            data: ArticleInsertData(
                author: author,
                summary: summary,
                content: html,
                imageURL: episode.stillURL ?? show.artworkURL,
                publishedDate: publishedDate
            )
        )
    }
}
