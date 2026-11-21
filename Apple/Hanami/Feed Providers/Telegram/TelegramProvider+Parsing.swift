import Foundation
import SwiftSoup

nonisolated private let telegramBackgroundImageRegex = try? NSRegularExpression(
    pattern: #"background-image:\s*url\(['"]?([^'")]+)['"]?\)"#
)

nonisolated extension TelegramProvider {

    static func parseChannelPage(_ html: String, channel: String) -> TelegramChannelFetchResult? {
        guard let document = try? SwiftSoup.parse(html, "https://t.me/"),
              (try? document.select(".tgme_channel_history").first()) != nil,
              let messages = try? document.select("div.tgme_widget_message[data-post]") else {
            return nil
        }
        document.outputSettings().prettyPrint(pretty: false)
        let title = metaContent("og:title", in: document)
            ?? text(of: ".tgme_channel_info_header_title", in: document)
        let avatarURL = metaContent("og:image", in: document)
            ?? (try? document.select(".tgme_page_photo_image img").first()?.attr("src"))
        let posts = messages.array().compactMap { parsePost($0) }
        return TelegramChannelFetchResult(
            title: title,
            avatarURL: avatarURL.flatMap { $0.isEmpty ? nil : $0 },
            posts: posts
        )
    }

    private static func parsePost(_ message: Element) -> ParsedTelegramPost? {
        guard !message.hasClass("service_message"),
              let postPath = try? message.attr("data-post"),
              postPath.contains("/") else { return nil }

        var sections: [String] = []
        if let forwardedFrom = text(of: ".tgme_widget_message_forwarded_from_name", in: message) {
            sections.append("Forwarded from \(forwardedFrom)")
        }
        let body = bodyText(in: message)
        if let formatted = body?.formatted {
            sections.append(formatted)
        }
        sections.append(contentsOf: attachmentSections(in: message))

        let dateString = try? message.select(".tgme_widget_message_date time[datetime]").first()?.attr("datetime")
        return ParsedTelegramPost(
            url: "https://t.me/\(postPath)",
            headline: body?.headline,
            text: sections.joined(separator: "\n\n"),
            imageURLs: imageURLs(in: message),
            mediaLabel: mediaLabel(in: message),
            publishedDate: dateString.flatMap { RSSParser().parseDate($0) }
        )
    }

    private static func bodyText(in message: Element) -> (formatted: String?, headline: String?)? {
        guard let element = try? message.select(".tgme_widget_message_text.js-message_text").first() else {
            return nil
        }
        for emoji in (try? element.select("tg-emoji, i.emoji").array()) ?? [] {
            let glyph = (try? emoji.text()) ?? ""
            _ = try? emoji.before(TextNode(glyph, nil))
            _ = try? emoji.remove()
        }
        // Telegram double-escapes ampersands inside link targets.
        for link in (try? element.select("a[href]").array()) ?? [] {
            let href = (try? link.attr("href")) ?? ""
            _ = try? link.attr("href", href.replacingOccurrences(of: "&amp;", with: "&"))
        }
        guard let html = try? element.html() else { return nil }
        let helper = RSSParser()
        let plainText = helper.cleanHTML(
            html.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        )
        return (
            helper.cleanHTMLPreservingStructure(html, baseURL: URL(string: "https://t.me/")),
            plainText?.split(whereSeparator: \.isNewline).first.map(String.init)
        )
    }

    private static func attachmentSections(in message: Element) -> [String] {
        var sections: [String] = []
        if let question = text(of: ".tgme_widget_message_poll_question", in: message) {
            let options = ((try? message.select(".tgme_widget_message_poll_option_text").array()) ?? [])
                .compactMap { try? $0.text() }
                .map { "• \($0)" }
            sections.append(([question] + options).joined(separator: "\n"))
        }
        if let documentTitle = text(of: ".tgme_widget_message_document_title", in: message) {
            sections.append(documentTitle)
        }
        if let preview = try? message.select("a.tgme_widget_message_link_preview").first(),
           let previewTitle = text(of: ".link_preview_title", in: preview)
            ?? text(of: ".link_preview_site_name", in: preview) {
            let href = ((try? preview.attr("href")) ?? "").replacingOccurrences(of: "&amp;", with: "&")
            let heading = href.isEmpty ? previewTitle : "[\(previewTitle)](\(href))"
            let description = text(of: ".link_preview_description", in: preview)
            sections.append([heading, description].compactMap { $0 }.joined(separator: "\n"))
        }
        return sections
    }

    private static func imageURLs(in message: Element) -> [String] {
        let selectors = [
            "a.tgme_widget_message_photo_wrap",
            ".tgme_widget_message_video_thumb",
            ".tgme_widget_message_roundvideo_thumb",
            ".link_preview_image",
            ".link_preview_right_image"
        ]
        var urls: [String] = []
        for selector in selectors {
            for element in (try? message.select(selector).array()) ?? [] {
                guard let style = try? element.attr("style"),
                      let url = backgroundImageURL(in: style),
                      !urls.contains(url) else { continue }
                urls.append(url)
            }
        }
        if urls.isEmpty,
           let sticker = try? message.select(".tgme_widget_message_sticker").first(),
           let webp = try? sticker.attr("data-webp"), !webp.isEmpty {
            urls.append(webp)
        }
        return urls
    }

    private static func mediaLabel(in message: Element) -> String? {
        let labels: [(selector: String, label: String)] = [
            (".tgme_widget_message_poll", "📊 Poll"),
            (".tgme_widget_message_video_player, .tgme_widget_message_roundvideo_player", "🎬 Video"),
            ("a.tgme_widget_message_photo_wrap", "🖼 Photo"),
            (".tgme_widget_message_voice_player", "🎤 Voice message"),
            (".tgme_widget_message_document", "📎 File"),
            (".tgme_widget_message_sticker_wrap", "Sticker")
        ]
        return labels.first { (try? message.select($0.selector).first()) != nil }?.label
    }

    private static func backgroundImageURL(in style: String) -> String? {
        guard let regex = telegramBackgroundImageRegex,
              let match = regex.firstMatch(in: style, range: NSRange(style.startIndex..., in: style)),
              let range = Range(match.range(at: 1), in: style) else { return nil }
        let url = String(style[range])
        return url.hasPrefix("//") ? "https:\(url)" : url
    }

    private static func metaContent(_ property: String, in document: Document) -> String? {
        guard let content = try? document.select("meta[property=\(property)]").first()?.attr("content") else {
            return nil
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func text(of selector: String, in element: Element) -> String? {
        guard let value = try? element.select(selector).first()?.text() else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
