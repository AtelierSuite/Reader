import Foundation

public nonisolated enum FeedParser {

    public static func parse(data: Data) -> ParsedFeed? {
        if looksLikeJSON(data) {
            return JSONFeedParser.parse(data: data)
        }
        return RSSParser().parse(data: data)
    }

    public static func looksLikeJSON(_ data: Data) -> Bool {
        let byteOrderMark: [UInt8] = [0xEF, 0xBB, 0xBF]
        let body = data.starts(with: byteOrderMark) ? data.dropFirst(byteOrderMark.count) : data[...]
        let whitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]
        return body.first { !whitespace.contains($0) } == UInt8(ascii: "{")
    }
}
