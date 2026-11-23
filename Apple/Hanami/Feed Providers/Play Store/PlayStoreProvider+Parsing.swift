import Foundation

nonisolated private let dataCallbackRegex = try? NSRegularExpression(
    pattern: #"AF_initDataCallback\(\{key:\s*'(ds:\d+)'[^}]*?data:(\[.*?\])\s*,\s*sideChannel:"#,
    options: .dotMatchesLineSeparators
)

nonisolated private let ogTitleRegex = try? NSRegularExpression(
    pattern: #"<meta[^>]+property="og:title"[^>]+content="([^"]+)""#,
    options: .caseInsensitive
)

nonisolated private let ogImageRegex = try? NSRegularExpression(
    pattern: #"<meta[^>]+property="og:image"[^>]+content="([^"]+)""#,
    options: .caseInsensitive
)

nonisolated extension PlayStoreProvider {

    static func parseAppDetails(from html: String, packageIdentifier: String) -> PlayStoreAppDetails? {
        let blocks = extractDataBlocks(from: html)
        guard let detailsBlock = blocks["ds:5"],
              let rootArray = arrayValue(at: [1, 2], in: detailsBlock),
              let title = stringValue(at: [0, 0], in: rootArray),
              !title.isEmpty else { return nil }

        let developerName = stringValue(at: [68, 0], in: rootArray)
        let iconURL = stringValue(at: [95, 0, 3, 2], in: rootArray)
        let version = stringValue(at: [140, 0, 0, 0], in: rootArray)
        let releaseNotesHTML = stringValue(at: [144, 1, 1], in: rootArray)
        let summary = stringValue(at: [73, 0, 1], in: rootArray)

        let updatedDate: Date?
        if let timestamp = numberValue(at: [145, 0, 1, 0], in: rootArray) {
            updatedDate = Date(timeIntervalSince1970: timestamp)
        } else {
            updatedDate = nil
        }

        return PlayStoreAppDetails(
            packageIdentifier: packageIdentifier,
            title: title,
            developerName: developerName,
            iconURL: iconURL,
            version: version,
            releaseNotesHTML: releaseNotesHTML,
            updatedDate: updatedDate,
            summary: summary
        )
    }

    static func parseDeveloperPage(from html: String, fallbackName: String?) -> PlayStoreDeveloperPage {
        let blocks = extractDataBlocks(from: html)
        var parsedApps: [PlayStoreDeveloperApp] = []
        var seenPackages: Set<String> = []

        for blockKey in ["ds:3", "ds:4"] {
            if let block = blocks[blockKey] {
                collectDeveloperApps(from: block, into: &parsedApps, seenPackages: &seenPackages)
            }
        }

        let developerName = parsedApps.lazy.compactMap(\.developerName).first
            ?? developerNameFromOpenGraph(in: html)
            ?? fallbackName

        let iconURL = firstRegexCapture(ogImageRegex, in: html).flatMap { candidate in
            candidate.contains("play-lh.googleusercontent.com") ? candidate : nil
        }

        return PlayStoreDeveloperPage(
            developerName: developerName,
            iconURL: iconURL,
            apps: parsedApps
        )
    }

    static func extractDataBlocks(from html: String) -> [String: Any] {
        guard let regex = dataCallbackRegex else { return [:] }
        let fullRange = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: fullRange)
        var blocks: [String: Any] = [:]
        for match in matches {
            guard let keyRange = Range(match.range(at: 1), in: html),
                  let dataRange = Range(match.range(at: 2), in: html) else { continue }
            let blockKey = String(html[keyRange])
            let jsonString = String(html[dataRange])
            if let jsonObject = try? JSONSerialization.jsonObject(with: Data(jsonString.utf8)) {
                blocks[blockKey] = jsonObject
            }
        }
        return blocks
    }

    private static func collectDeveloperApps(
        from node: Any,
        into results: inout [PlayStoreDeveloperApp],
        seenPackages: inout Set<String>
    ) {
        guard let array = node as? [Any] else { return }
        if let app = parseDeveloperAppCard(from: array) {
            if seenPackages.insert(app.packageIdentifier).inserted {
                results.append(app)
            }
            return
        }
        for element in array {
            collectDeveloperApps(from: element, into: &results, seenPackages: &seenPackages)
        }
    }

    private static func parseDeveloperAppCard(from array: [Any]) -> PlayStoreDeveloperApp? {
        guard array.count >= 15,
              let identity = array[0] as? [Any],
              identity.count >= 2,
              let packageIdentifier = identity[0] as? String,
              let entityType = identity[1] as? Int,
              entityType == 7,
              let title = array[3] as? String,
              !title.isEmpty,
              let detailsPath = stringValue(at: [10, 4, 2], in: array),
              detailsPath.hasPrefix("/store/apps/details?id=") else { return nil }

        let iconURL = stringValue(at: [1, 3, 2], in: array)
        let descriptionHTML = stringValue(at: [13, 1], in: array)
        let developerName = array[14] as? String

        return PlayStoreDeveloperApp(
            packageIdentifier: packageIdentifier,
            title: title,
            developerName: developerName,
            iconURL: iconURL,
            descriptionHTML: descriptionHTML
        )
    }

    private static func developerNameFromOpenGraph(in html: String) -> String? {
        guard let rawTitle = firstRegexCapture(ogTitleRegex, in: html) else { return nil }
        let decoded = RSSParser.decodeHTMLEntities(rawTitle)
        if let prefixRange = decoded.range(of: "Android Apps by "),
           let suffixRange = decoded.range(of: " on Google Play", range: prefixRange.upperBound..<decoded.endIndex) {
            let extracted = String(decoded[prefixRange.upperBound..<suffixRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !extracted.isEmpty { return extracted }
        }
        return decoded.isEmpty ? nil : decoded
    }

    private static func firstRegexCapture(_ regex: NSRegularExpression?, in text: String) -> String? {
        guard let regex,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }

    private static func value(at path: [Int], in root: Any) -> Any? {
        var current: Any = root
        for index in path {
            guard let array = current as? [Any], index >= 0, index < array.count else { return nil }
            current = array[index]
        }
        return current
    }

    private static func arrayValue(at path: [Int], in root: Any) -> [Any]? {
        value(at: path, in: root) as? [Any]
    }

    private static func stringValue(at path: [Int], in root: Any) -> String? {
        guard let text = value(at: path, in: root) as? String, !text.isEmpty else { return nil }
        return text
    }

    private static func numberValue(at path: [Int], in root: Any) -> Double? {
        if let doubleValue = value(at: path, in: root) as? Double { return doubleValue }
        if let integerValue = value(at: path, in: root) as? Int { return Double(integerValue) }
        return nil
    }
}
