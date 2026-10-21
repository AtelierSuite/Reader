import Foundation

nonisolated struct PodcastEpisode: Sendable {
    let title: String
    let audioURL: URL
    let mimeType: String?
    let publishedDate: String?
    let duration: String?
}

nonisolated enum PodcastFeed {

    static func episodes(at feedURL: URL) async throws -> [PodcastEpisode] {
        let (data, response) = try await URLSession.shared.data(from: feedURL)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw HarnessError.feedUnreadable("HTTP \(httpResponse.statusCode)")
        }
        let delegate = PodcastFeedParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw HarnessError.feedUnreadable(parser.parserError?.localizedDescription ?? "not valid XML")
        }
        return delegate.episodes
    }
}

private nonisolated final class PodcastFeedParserDelegate: NSObject, XMLParserDelegate {

    private(set) var episodes: [PodcastEpisode] = []
    private var isInsideItem = false
    private var text = ""
    private var title = ""
    private var audioURL: URL?
    private var mimeType: String?
    private var publishedDate: String?
    private var duration: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        text = ""
        switch elementName {
        case "item":
            isInsideItem = true
            title = ""
            audioURL = nil
            mimeType = nil
            publishedDate = nil
            duration = nil
        case "enclosure" where isInsideItem:
            let type = attributes["type"]
            guard type == nil || type?.hasPrefix("audio/") == true || type == "video/mp4" else { return }
            audioURL = attributes["url"].flatMap(URL.init(string:))
            mimeType = type
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(bytes: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        guard isInsideItem else { return }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "title" where title.isEmpty:
            title = trimmedText
        case "pubDate":
            publishedDate = trimmedText
        case "itunes:duration":
            duration = trimmedText
        case "item":
            isInsideItem = false
            if let audioURL {
                episodes.append(PodcastEpisode(
                    title: title.isEmpty ? audioURL.lastPathComponent : title,
                    audioURL: audioURL,
                    mimeType: mimeType,
                    publishedDate: publishedDate,
                    duration: duration
                ))
            }
        default:
            break
        }
    }
}
