import Foundation

nonisolated extension MastodonProvider {

    static func articleItems(from statuses: [MastodonStatus]) -> [ArticleInsertItem] {
        statuses.compactMap(articleItem(from:))
    }

    private static func articleItem(from status: MastodonStatus) -> ArticleInsertItem? {
        let postURL = status.reblog?.url ?? status.reblog?.uri ?? status.url ?? status.uri
        guard let postURL, !postURL.isEmpty else { return nil }

        let author = status.reblog?.displayAuthor ?? status.displayAuthor
        let rawHTML = status.reblog?.content ?? status.content
        let spoilerText = (status.reblog?.spoilerText ?? status.spoilerText)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let mediaAttachments = status.reblog?.mediaAttachments ?? status.mediaAttachments ?? []
        let card = status.reblog?.card ?? status.card

        let cleanedText = MastodonCommentsProvider.cleanCommentText(rawHTML)
        let title = makeTitle(cleanedText: cleanedText, spoilerText: spoilerText, author: author)
        let summary = makeSummary(cleanedText: cleanedText, spoilerText: spoilerText)
        let contentHTML = makeContentHTML(rawHTML: rawHTML, spoilerText: spoilerText, mediaAttachments: mediaAttachments)

        let imageAttachments = mediaAttachments.filter { $0.type == "image" }
        let imageURLs = imageAttachments.compactMap { $0.url ?? $0.previewURL }
        let firstPreviewURL = mediaAttachments.first.flatMap { $0.previewURL ?? $0.url }
        let primaryImageURL = imageURLs.first ?? firstPreviewURL ?? card?.image

        return ArticleInsertItem(
            title: title,
            url: postURL,
            data: ArticleInsertData(
                author: author,
                summary: summary,
                content: contentHTML,
                imageURL: primaryImageURL,
                carouselImageURLs: imageURLs.count > 1 ? imageURLs : [],
                publishedDate: status.createdDate
            )
        )
    }

    private static func makeTitle(cleanedText: String, spoilerText: String, author: String) -> String {
        if !spoilerText.isEmpty {
            return String(spoilerText.prefix(200))
        }
        let firstLine = cleanedText
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !firstLine.isEmpty {
            return String(firstLine.prefix(200))
        }
        return "Post by \(author)"
    }

    private static func makeSummary(cleanedText: String, spoilerText: String) -> String? {
        if spoilerText.isEmpty {
            return cleanedText.isEmpty ? nil : cleanedText
        }
        if cleanedText.isEmpty {
            return spoilerText
        }
        return "\(spoilerText)\n\n\(cleanedText)"
    }

    private static func makeContentHTML(
        rawHTML: String,
        spoilerText: String,
        mediaAttachments: [MastodonMediaAttachment]
    ) -> String? {
        var html = ""
        if !spoilerText.isEmpty {
            html += "<p><strong>\(htmlEscape(spoilerText))</strong></p>"
        }
        html += rawHTML
        for attachment in mediaAttachments where attachment.type == "image" {
            guard let sourceURL = attachment.url ?? attachment.previewURL else { continue }
            let altText = attachment.description ?? ""
            html += "<figure><img src=\"\(htmlEscape(sourceURL))\" alt=\"\(htmlEscape(altText))\"></figure>"
        }
        return html.isEmpty ? nil : html
    }

    private static func htmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
