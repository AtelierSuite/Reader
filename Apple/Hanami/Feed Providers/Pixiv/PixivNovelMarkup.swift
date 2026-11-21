import Foundation

/// Converts Pixiv novel markup (`[newpage]`, `[chapter:]`, `[[rb:]]`, `[[jumpuri:]]`, embedded images) to HTML.
nonisolated struct PixivNovelMarkup {

    let illustImageURLs: [String: String]
    let uploadedImageURLs: [String: String]

    private static let tagRegex = try? NSRegularExpression(pattern: [
        #"\[\[rb:(.+?)>(.+?)\]\]"#,
        #"\[\[jumpuri:(.+?)>\s*(\S+?)\s*\]\]"#,
        #"\[chapter:(.+?)\]"#,
        #"\[newpage\]"#,
        #"\[jump:\d+\]"#,
        #"\[pixivimage:([\d-]+)\]"#,
        #"\[uploadedimage:(\d+)\]"#
    ].joined(separator: "|"))

    private static let pixivImageRegex = try? NSRegularExpression(pattern: #"\[pixivimage:([\d-]+)\]"#)

    init(illustImageURLs: [String: String] = [:], uploadedImageURLs: [String: String] = [:]) {
        self.illustImageURLs = illustImageURLs
        self.uploadedImageURLs = uploadedImageURLs
    }

    static func pixivImageReferences(in text: String) -> [String] {
        guard let pixivImageRegex else { return [] }
        let matches = pixivImageRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let references = matches.compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
        var seen = Set<String>()
        return references.filter { seen.insert($0).inserted }
    }

    func html(from text: String) -> String {
        var blocks: [String] = []
        var paragraphLines: [String] = []
        let flushParagraph = {
            if !paragraphLines.isEmpty {
                blocks.append("<p>\(paragraphLines.joined(separator: "<br>"))</p>")
                paragraphLines.removeAll()
            }
        }
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushParagraph()
                continue
            }
            for segment in convertedSegments(in: line) {
                if segment.isBlock {
                    flushParagraph()
                    blocks.append(segment.html)
                } else if !segment.html.trimmingCharacters(in: .whitespaces).isEmpty {
                    paragraphLines.append(segment.html)
                }
            }
        }
        flushParagraph()
        return blocks.joined(separator: "\n")
    }

    private struct Segment {
        let html: String
        let isBlock: Bool
    }

    private func convertedSegments(in line: String) -> [Segment] {
        guard let regex = Self.tagRegex else { return [Segment(html: escaped(line), isBlock: false)] }
        var segments: [Segment] = []
        var inline = ""
        var cursor = line.startIndex
        for match in regex.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
            guard let matchRange = Range(match.range, in: line) else { continue }
            inline += escaped(String(line[cursor..<matchRange.lowerBound]))
            cursor = matchRange.upperBound
            let capture = { (index: Int) -> String? in
                Range(match.range(at: index), in: line).map {
                    String(line[$0]).trimmingCharacters(in: .whitespaces)
                }
            }
            if let base = capture(1), let reading = capture(2) {
                inline += "<ruby>\(escaped(base))<rt>\(escaped(reading))</rt></ruby>"
            } else if let label = capture(3), let target = capture(4) {
                inline += "<a href=\"\(escapedAttribute(target))\">\(escaped(label))</a>"
            } else if let block = blockHTML(chapter: capture(5), illust: capture(6), uploaded: capture(7),
                                            tag: String(line[matchRange])) {
                if !inline.isEmpty {
                    segments.append(Segment(html: inline, isBlock: false))
                    inline = ""
                }
                segments.append(Segment(html: block, isBlock: true))
            }
        }
        inline += escaped(String(line[cursor...]))
        if !inline.isEmpty {
            segments.append(Segment(html: inline, isBlock: false))
        }
        return segments
    }

    private func blockHTML(chapter: String?, illust: String?, uploaded: String?, tag: String) -> String? {
        if let chapter {
            return "<h2>\(escaped(chapter))</h2>"
        }
        if tag == "[newpage]" {
            return "<p>* * *</p>"
        }
        if let illust {
            let artworkID = illust.split(separator: "-").first.map(String.init) ?? illust
            guard let imageURL = illustImageURLs[illust] else {
                let artworkURL = "\(PixivProvider.origin)/artworks/\(artworkID)"
                return "<p><a href=\"\(artworkURL)\">\(artworkURL)</a></p>"
            }
            return "<figure><img src=\"\(escapedAttribute(imageURL))\"></figure>"
        }
        if let uploaded, let imageURL = uploadedImageURLs[uploaded] {
            return "<figure><img src=\"\(escapedAttribute(imageURL))\"></figure>"
        }
        return nil
    }

    private func escaped(_ text: String) -> String {
        RSSParser.escapeXMLText(text)
    }

    private func escapedAttribute(_ text: String) -> String {
        RSSParser.escapeXMLAttribute(text)
    }
}
