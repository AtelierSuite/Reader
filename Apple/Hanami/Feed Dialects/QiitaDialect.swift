import Foundation

nonisolated enum QiitaDialect: FeedDialect {

    static func matches(feedURL: URL, feed _: ParsedFeed) -> Bool {
        feedURL.host?.lowercased() == "qiita.com"
    }

    static func refine(_ article: ParsedArticle, feedURL _: URL) -> ParsedArticle {
        var refined = article
        refined.url = withoutCampaignParameters(article.url)
        return refined
    }

    static func withoutCampaignParameters(_ urlString: String) -> String {
        guard var components = URLComponents(string: urlString), let items = components.queryItems else {
            return urlString
        }
        let kept = items.filter { !$0.name.hasPrefix("utm_") }
        components.queryItems = kept.isEmpty ? nil : kept
        return components.string ?? urlString
    }
}
