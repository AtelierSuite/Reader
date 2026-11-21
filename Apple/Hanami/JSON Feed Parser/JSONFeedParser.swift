import Foundation

public nonisolated enum JSONFeedParser {

    public static func parse(data: Data) -> ParsedFeed? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = root["version"] as? String,
              version.contains("jsonfeed.org/version/"),
              let items = root["items"] as? [[String: Any]] else {
            return nil
        }
        let feedAuthor = authorName(in: root)
        let articles = items.compactMap { article(from: $0, feedAuthor: feedAuthor) }
        return ParsedFeed(
            title: string(root["title"]) ?? "",
            siteURL: string(root["home_page_url"]) ?? "",
            description: string(root["description"]) ?? "",
            articles: articles
        )
    }

    static func string(_ value: Any?) -> String? {
        let text: String
        switch value {
        case let stringValue as String: text = stringValue
        case let numberValue as NSNumber: text = numberValue.stringValue
        default: return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func authorName(in object: [String: Any]) -> String? {
        if let authors = object["authors"] as? [[String: Any]],
           let name = authors.lazy.compactMap({ string($0["name"]) }).first {
            return name
        }
        return string((object["author"] as? [String: Any])?["name"])
    }
}
