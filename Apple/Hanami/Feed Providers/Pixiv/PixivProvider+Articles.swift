import Foundation

nonisolated extension PixivProvider {

    private static let jumpLinkRegex = try? NSRegularExpression(pattern: #"href="/jump\.php\?([^"]+)""#)

    static func articleItem(for artwork: PixivArtwork, detail: PixivIllustDetail?) -> ArticleInsertItem {
        let pageURLs = PixivImageURLs.pageImageURLs(
            from: detail?.urls?.regular ?? artwork.imageURL, pageCount: artwork.pageCount
        )
        let captionHTML = detail?.description.map(unwrappingJumpLinks) ?? ""
        let imagesHTML = pageURLs
            .map { "<figure><img src=\"\(RSSParser.escapeXMLAttribute($0))\"></figure>" }
            .joined()
        let captionParagraph = captionHTML.isEmpty ? "" : "<p>\(captionHTML)</p>"
        return ArticleInsertItem(
            title: artwork.title,
            url: artwork.pageURL,
            data: ArticleInsertData(
                author: detail?.userName ?? artwork.authorName,
                summary: plainText(fromHTML: captionHTML),
                content: captionParagraph + imagesHTML,
                imageURL: pageURLs.first,
                carouselImageURLs: pageURLs.count > 1 ? pageURLs : [],
                publishedDate: artwork.publishedDate
            )
        )
    }

    static func articleItem(for novel: PixivNovel) async -> ArticleInsertItem {
        let captionHTML = novel.captionHTML.map(unwrappingJumpLinks) ?? ""
        var content = captionHTML.isEmpty ? nil : "<p>\(captionHTML)</p>"
        var coverURL = novel.coverURL
        if let detail = try? await fetchNovelDetail(novel.id), let text = detail.content {
            let references = PixivNovelMarkup.pixivImageReferences(in: text)
            let markup = PixivNovelMarkup(
                illustImageURLs: await fetchInsertedIllustURLs(novelID: novel.id, references: references),
                uploadedImageURLs: detail.uploadedImageURLs
            )
            content = markup.html(from: text)
            coverURL = detail.coverUrl ?? coverURL
        }
        return ArticleInsertItem(
            title: novel.title,
            url: novel.pageURL,
            data: ArticleInsertData(
                author: novel.authorName,
                summary: plainText(fromHTML: captionHTML),
                content: content,
                imageURL: coverURL,
                publishedDate: novel.publishedDate
            )
        )
    }

    static func unwrappingJumpLinks(_ html: String) -> String {
        guard html.contains("/jump.php?"), let jumpLinkRegex else { return html }
        let nsHTML = html as NSString
        var result = html
        for match in jumpLinkRegex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length)).reversed() {
            let encodedTarget = nsHTML.substring(with: match.range(at: 1))
            let target = encodedTarget.removingPercentEncoding ?? encodedTarget
            result = (result as NSString).replacingCharacters(
                in: match.range, with: "href=\"\(RSSParser.escapeXMLAttribute(target))\""
            )
        }
        return result
    }

    static func plainText(fromHTML html: String) -> String? {
        let withBreaks = html.replacingOccurrences(
            of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive]
        )
        let text = RSSParser.decodeHTMLEntities(RSSParser.stripHTMLTags(withBreaks))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
