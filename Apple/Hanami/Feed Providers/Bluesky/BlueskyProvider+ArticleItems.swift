import Foundation

extension BlueskyProvider {

    nonisolated static func articleItems(from posts: [ParsedBlueskyPost]) -> [ArticleInsertItem] {
        posts.map { post in
            let title = post.text.isEmpty
                ? "Post by @\(post.authorHandle)"
                : String(post.text.prefix(200))
            return ArticleInsertItem(
                title: title,
                url: post.url,
                data: ArticleInsertData(
                    author: post.author.isEmpty ? "@\(post.authorHandle)" : post.author,
                    summary: post.text.isEmpty ? nil : post.text,
                    content: contentHTML(for: post),
                    imageURL: post.images.first?.thumbURL ?? post.videoThumbnailURL,
                    carouselImageURLs: post.images.count > 1 ? post.images.map(\.thumbURL) : [],
                    publishedDate: post.publishedDate
                )
            )
        }
    }

    private nonisolated static func contentHTML(for post: ParsedBlueskyPost) -> String? {
        var html = paragraphHTML(post.text) + figuresHTML(post.images)
        if let quote = post.quote {
            let name = quote.author.isEmpty ? "@\(quote.authorHandle)" : "\(quote.author) (@\(quote.authorHandle))"
            html += "<blockquote cite=\"\(htmlEscape(quote.url))\">"
                + "<p><a href=\"\(htmlEscape(quote.url))\">\(htmlEscape(name))</a></p>"
                + paragraphHTML(quote.text) + figuresHTML(quote.images)
                + "</blockquote>"
        }
        return html.isEmpty ? nil : html
    }

    private nonisolated static func paragraphHTML(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        return "<p>\(htmlEscape(text).replacingOccurrences(of: "\n", with: "<br>"))</p>"
    }

    private nonisolated static func figuresHTML(_ images: [ParsedBlueskyImage]) -> String {
        images.map { image in
            "<figure><img src=\"\(htmlEscape(image.fullsizeURL))\" alt=\"\(htmlEscape(image.alt))\"></figure>"
        }.joined()
    }

    private nonisolated static func htmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
