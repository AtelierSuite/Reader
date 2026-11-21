import Foundation

nonisolated private let linkTagRegex = try? NSRegularExpression(
    pattern: #"<link\b[^>]*>"#,
    options: .caseInsensitive
)

nonisolated private let linkTagAttributeRegexes: [String: NSRegularExpression] = {
    var regexes: [String: NSRegularExpression] = [:]
    for name in ["href", "title", "type", "rel"] {
        let pattern = #"(?<![-\w])\#(name)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            regexes[name] = regex
        }
    }
    return regexes
}()

nonisolated private let xmlFeedLinkTypes = ["application/rss+xml", "application/atom+xml", "application/rdf+xml"]

nonisolated private let feedAnchorRegex = try? NSRegularExpression(
    pattern: #"<a\s[^>]*href\s*=\s*["']([^"']*)["'][^>]*>(.*?)</a>"#,
    options: [.caseInsensitive, .dotMatchesLineSeparators]
)

nonisolated private let baseHrefRegex = try? NSRegularExpression(
    pattern: #"<base\b[^>]*\bhref\s*=\s*["']([^"']*)["']"#,
    options: .caseInsensitive
)

public extension FeedDiscovery {

    // MARK: - HTML Link Discovery

    func discoverFromHTML(domain: String) async -> [DiscoveredFeed] {
        guard let url = URL(string: "https://\(domain)") else { return [] }
        return await discoverFromHTML(url: url)
    }

    func discoverFromHTML(url: URL) async -> [DiscoveredFeed] {
        do {
            let (data, response) = try await URLSession.shared.data(for: .sakura(url: url))
            guard let html = HTMLDataDecoder.decode(data, response: response) else { return [] }
            return extractFeedLinks(from: html, baseURL: url)
        } catch {
            return []
        }
    }

    func extractFeedLinks(from html: String, baseURL: URL) -> [DiscoveredFeed] {
        let documentBase = documentBaseURL(in: html, fallback: baseURL)
        return feedLinkElements(in: html, siteURL: baseURL, base: documentBase)
            + feedAnchorElements(in: html, siteURL: baseURL, base: documentBase)
    }

    func resolveURL(_ href: String, base: URL) -> String? {
        let trimmed = RSSParser.decodeHTMLEntities(href)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed, relativeTo: base)?.absoluteURL.absoluteString
    }

    private func documentBaseURL(in html: String, fallback: URL) -> URL {
        guard let regex = baseHrefRegex else { return fallback }
        let nsHTML = html as NSString
        guard let match = regex.firstMatch(
            in: html, range: NSRange(location: 0, length: nsHTML.length)
        ), match.numberOfRanges >= 2 else { return fallback }
        let href = RSSParser.decodeHTMLEntities(nsHTML.substring(with: match.range(at: 1)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !href.isEmpty, let resolved = URL(string: href, relativeTo: fallback) else {
            return fallback
        }
        return resolved.absoluteURL
    }

    private func feedLinkElements(
        in html: String, siteURL: URL, base: URL
    ) -> [DiscoveredFeed] {
        guard let regex = linkTagRegex else { return [] }
        let nsHTML = html as NSString
        let tags = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
            .map { nsHTML.substring(with: $0.range) }
        let typedTags = tags.compactMap { tag -> (tag: String, type: String)? in
            guard let type = linkTagAttribute("type", in: tag)?.lowercased() else { return nil }
            return (tag, type)
        }
        let hasJSONFeedLink = typedTags.contains { $0.type.hasPrefix("application/feed+json") }
        return typedTags.compactMap { tag, type in
            let isXMLFeed = xmlFeedLinkTypes.contains { type.hasPrefix($0) }
            let isJSONFeed = type.hasPrefix("application/feed+json")
                || (!hasJSONFeedLink && isAlternateJSONLink(tag, type: type))
            guard isXMLFeed || isJSONFeed,
                  let href = linkTagAttribute("href", in: tag),
                  let feedURL = resolveURL(href, base: base) else { return nil }
            let rawTitle = linkTagAttribute("title", in: tag) ?? (isJSONFeed ? "JSON Feed" : "RSS Feed")
            return DiscoveredFeed(
                title: RSSParser.decodeHTMLEntities(rawTitle),
                url: feedURL,
                siteURL: siteURL.absoluteString
            )
        }
    }

    // Sites such as daringfireball.net advertise JSON Feed as plain application/json;
    // requiring rel=alternate keeps oEmbed and wp-json links out.
    private func isAlternateJSONLink(_ tag: String, type: String) -> Bool {
        let mediaType = type.split(separator: ";").first?.trimmingCharacters(in: .whitespaces)
        guard mediaType == "application/json",
              let relation = linkTagAttribute("rel", in: tag)?.lowercased(),
              let href = linkTagAttribute("href", in: tag) else { return false }
        return relation.split(separator: " ").contains("alternate") && !href.contains("/wp-json")
    }

    private func linkTagAttribute(_ name: String, in tag: String) -> String? {
        guard let regex = linkTagAttributeRegexes[name] else { return nil }
        let nsTag = tag as NSString
        guard let match = regex.firstMatch(
            in: tag, range: NSRange(location: 0, length: nsTag.length)
        ) else { return nil }
        for group in 1..<match.numberOfRanges where match.range(at: group).location != NSNotFound {
            return nsTag.substring(with: match.range(at: group))
        }
        return nil
    }

    private func feedAnchorElements(
        in html: String, siteURL: URL, base: URL
    ) -> [DiscoveredFeed] {
        guard let regex = feedAnchorRegex else { return [] }
        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        return matches.compactMap { match in
            guard match.numberOfRanges >= 3 else { return nil }
            let text = RSSParser.stripHTMLTags(nsHTML.substring(with: match.range(at: 2)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercasedText = text.lowercased()
            guard lowercasedText == "rss feed" || lowercasedText == "rss" else { return nil }
            guard let feedURL = resolveURL(
                nsHTML.substring(with: match.range(at: 1)), base: base
            ) else { return nil }
            return DiscoveredFeed(title: text, url: feedURL, siteURL: siteURL.absoluteString)
        }
    }
}
