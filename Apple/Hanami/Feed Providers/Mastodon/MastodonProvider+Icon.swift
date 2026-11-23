import Foundation

nonisolated private let iconLinkTagRegex = try? NSRegularExpression(
    pattern: #"<link\b[^>]*>"#,
    options: .caseInsensitive
)

nonisolated private let iconAttributeRegexes: [String: NSRegularExpression] = {
    var regexes: [String: NSRegularExpression] = [:]
    for name in ["href", "rel", "sizes"] {
        let pattern = #"(?<![-\w])\#(name)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            regexes[name] = regex
        }
    }
    return regexes
}()

nonisolated private let siteUploadSizeSegmentRegex = try? NSRegularExpression(
    pattern: #"(/site_uploads/files/[^/]+/[^/]+/[^/]+/)\d+(/[^/?#]+)"#
)

nonisolated extension MastodonProvider {

    static func fetchInstanceIconURL(host: String) async -> String? {
        if let customIcon = await fetchInstance(host: host)?.customIconURL {
            return customIcon
        }
        return await fetchCustomFaviconURL(host: host)
    }

    private static func fetchCustomFaviconURL(host: String) async -> String? {
        guard let pageURL = URL(string: "https://\(host)") else { return nil }
        let request = URLRequest.sakura(url: pageURL, timeoutInterval: 6)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let html = HTMLDataDecoder.decode(data, response: response) else {
            return nil
        }

        let candidates = customFaviconCandidates(in: html, baseURL: pageURL)
        guard let bestCandidate = candidates.max(by: { $0.dimension < $1.dimension }) else {
            return nil
        }

        if let originalURL = originalSiteUploadURL(from: bestCandidate.url),
           await urlReturnsOK(originalURL) {
            return originalURL.absoluteString
        }
        return bestCandidate.url.absoluteString
    }

    private static func customFaviconCandidates(
        in html: String,
        baseURL: URL
    ) -> [(url: URL, dimension: Int)] {
        guard let regex = iconLinkTagRegex else { return [] }
        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        return matches.compactMap { match in
            let tag = nsHTML.substring(with: match.range)
            guard let relation = attributeValue("rel", in: tag)?.lowercased() else { return nil }
            let relationTokens = relation.split(separator: " ")
            guard relationTokens.contains("icon") || relationTokens.contains("apple-touch-icon") else {
                return nil
            }
            guard let href = attributeValue("href", in: tag),
                  !href.contains("/packs/assets/"),
                  let resolved = URL(string: href, relativeTo: baseURL)?.absoluteURL else {
                return nil
            }
            let dimension = parsedDimension(from: attributeValue("sizes", in: tag))
            return (resolved, dimension)
        }
    }

    private static func attributeValue(_ name: String, in tag: String) -> String? {
        guard let regex = iconAttributeRegexes[name] else { return nil }
        let nsTag = tag as NSString
        guard let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: nsTag.length)) else {
            return nil
        }
        for group in 1..<match.numberOfRanges where match.range(at: group).location != NSNotFound {
            return nsTag.substring(with: match.range(at: group))
        }
        return nil
    }

    private static func parsedDimension(from sizes: String?) -> Int {
        guard let sizes, let firstToken = sizes.split(separator: " ").first else { return 0 }
        let parts = firstToken.lowercased().split(separator: "x")
        return parts.first.flatMap { Int($0) } ?? 0
    }

    /// Mastodon resizes uploaded favicons to 16/32/48px but keeps the full-resolution upload under `/original/`.
    private static func originalSiteUploadURL(from url: URL) -> URL? {
        guard let regex = siteUploadSizeSegmentRegex else { return nil }
        let absoluteString = url.absoluteString
        let range = NSRange(location: 0, length: (absoluteString as NSString).length)
        guard regex.firstMatch(in: absoluteString, range: range) != nil else { return nil }
        let replaced = regex.stringByReplacingMatches(
            in: absoluteString,
            range: range,
            withTemplate: "$1original$2"
        )
        return URL(string: replaced)
    }

    private static func urlReturnsOK(_ url: URL) async -> Bool {
        var request = URLRequest.sakura(url: url, timeoutInterval: 4)
        request.httpMethod = "HEAD"
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        return httpResponse.statusCode == 200
    }
}
