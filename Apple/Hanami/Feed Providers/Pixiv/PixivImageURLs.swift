import Foundation

nonisolated enum PixivImageURLs {

    private static let pageImageRegex = try? NSRegularExpression(
        pattern: #"^https://i\.pximg\.net/(?:c/[^/]+/)?(?:img-master|custom-thumb)/img/"#
            + #"(.+?)_p0_(?:master|square|custom)1200\.jpg$"#
    )

    /// Turns any thumbnail or page image of a work into its 1200px page images, one per page.
    static func pageImageURLs(from imageURL: String?, pageCount: Int) -> [String] {
        guard let imageURL else { return [] }
        guard let pageImageRegex,
              let match = pageImageRegex.firstMatch(
                in: imageURL, range: NSRange(imageURL.startIndex..., in: imageURL)
              ),
              let pathRange = Range(match.range(at: 1), in: imageURL) else {
            return [imageURL]
        }
        let path = imageURL[pathRange]
        return (0..<max(pageCount, 1)).map { page in
            "https://i.pximg.net/img-master/img/\(path)_p\(page)_master1200.jpg"
        }
    }
}
