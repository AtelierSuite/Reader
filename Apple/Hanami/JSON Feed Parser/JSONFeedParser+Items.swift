import Foundation

nonisolated extension JSONFeedParser {

    static func article(from item: [String: Any], feedAuthor: String?) -> ParsedArticle? {
        guard let identifier = string(item["id"]) else { return nil }
        let attachment = audioAttachment(in: item)
        guard let url = string(item["url"])
            ?? string(item["external_url"])
            ?? (isWebURL(identifier) ? identifier : nil)
            ?? attachment?.url else {
            return nil
        }

        let helper = RSSParser()
        let contentHTML = string(item["content_html"])
            ?? string(item["content_text"]).map(paragraphHTML)
        let summarySource = string(item["summary"]) ?? contentHTML ?? ""
        let plainContent = contentHTML.flatMap { helper.cleanHTML($0) }
        guard let title = string(item["title"]) ?? plainContent.map(titleFromContent),
              !title.isEmpty else {
            return nil
        }

        let dateString = string(item["date_published"]) ?? string(item["date_modified"]) ?? ""
        return ParsedArticle(
            title: title,
            url: url,
            author: authorName(in: item) ?? feedAuthor,
            summary: helper.cleanHTMLPreservingStructure(summarySource, baseURL: URL(string: url)),
            content: contentHTML,
            imageURL: (string(item["image"])
                ?? string(item["banner_image"])
                ?? contentHTML.flatMap { helper.extractImageFromHTML($0) })
                .flatMap { absoluteURL($0, relativeTo: url) },
            publishedDate: helper.parseDate(dateString),
            audioURL: attachment?.url,
            duration: attachment?.duration
        )
    }

    private static func absoluteURL(_ reference: String, relativeTo base: String) -> String? {
        URL(string: reference, relativeTo: URL(string: base))?.absoluteURL.absoluteString
    }

    private static func isWebURL(_ text: String) -> Bool {
        guard let scheme = URL(string: text)?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    private static func titleFromContent(_ plainContent: String) -> String {
        let firstLine = plainContent
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? ""
        let limit = 100
        guard firstLine.count > limit else { return firstLine }
        return firstLine.prefix(limit).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func paragraphHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { paragraph in
                let escaped = RSSParser.escapeXMLText(paragraph)
                    .replacingOccurrences(of: "\n", with: "<br>")
                return "<p>\(escaped)</p>"
            }
            .joined()
    }

    private static func audioAttachment(in item: [String: Any]) -> (url: String, duration: Int?)? {
        guard let attachments = item["attachments"] as? [[String: Any]] else { return nil }
        for attachment in attachments {
            guard let mimeType = string(attachment["mime_type"])?.lowercased(),
                  mimeType.hasPrefix("audio/"),
                  let url = string(attachment["url"]) else { continue }
            let duration = (attachment["duration_in_seconds"] as? NSNumber)?.intValue
            return (url, duration)
        }
        return nil
    }
}
