import Foundation

nonisolated enum NetflixPageData {

    private static let contextMarker = "netflix.reactContext = "
    private static let contextTerminator = "};</script>"

    static func show(fromTitlePageHTML html: String) -> NetflixShow? {
        guard let context = reactContext(in: html),
              let pageData = firstValue(forKey: "webLoggedOutDetailPage_data", in: context) as? [String: Any],
              let videos = pageData["videos"] as? [[String: Any]],
              let video = videos.first else { return nil }
        return NetflixShow(video: video)
    }

    static func reactContext(in html: String) -> Any? {
        guard let start = html.range(of: contextMarker),
              let end = html.range(of: contextTerminator, range: start.upperBound..<html.endIndex)
        else { return nil }
        let script = html[start.upperBound..<end.lowerBound] + "}"
        guard let data = jsonFromJavaScriptLiteral(script).data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    /// The page embeds a JavaScript object literal whose strings use `\xNN` escapes, which JSON doesn't allow.
    static func jsonFromJavaScriptLiteral(_ script: Substring) -> String {
        var json = ""
        json.reserveCapacity(script.utf8.count)
        var index = script.startIndex
        while index < script.endIndex {
            let character = script[index]
            let next = script.index(after: index)
            guard character == "\\", next < script.endIndex else {
                json.append(character)
                index = next
                continue
            }
            let escaped = script[next]
            let afterEscape = script.index(after: next)
            if escaped == "x",
               let hexEnd = script.index(afterEscape, offsetBy: 2, limitedBy: script.endIndex),
               script[afterEscape..<hexEnd].allSatisfy(\.isHexDigit) {
                json += "\\u00" + script[afterEscape..<hexEnd]
                index = hexEnd
            } else if escaped == "'" {
                json.append("'")
                index = afterEscape
            } else {
                json.append(character)
                json.append(escaped)
                index = afterEscape
            }
        }
        return json
    }

    static func firstValue(forKey key: String, in object: Any) -> Any? {
        if let dictionary = object as? [String: Any] {
            if let value = dictionary[key] { return value }
            for value in dictionary.values {
                if let found = firstValue(forKey: key, in: value) { return found }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let found = firstValue(forKey: key, in: value) { return found }
            }
        }
        return nil
    }

    /// Localized labels such as シーズン5 come with zero-width characters between letters.
    static func text(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let cleaned = String(string.unicodeScalars.filter { !invisibleScalars.contains($0) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static let invisibleScalars: Set<Unicode.Scalar> = [
        "\u{FEFF}", "\u{200B}", "\u{200C}", "\u{200D}", "\u{2060}"
    ]

    static func imageURL(_ value: Any?) -> String? {
        guard let image = value as? [String: Any],
              image["available"] as? Bool != false,
              let url = image["url"] as? String, !url.isEmpty else { return nil }
        return url
    }

    static func edgeNodes(_ value: Any?) -> [[String: Any]] {
        guard let connection = value as? [String: Any],
              let edges = connection["edges"] as? [[String: Any]] else { return [] }
        return edges.compactMap { $0["node"] as? [String: Any] }
    }

    static func identifier(_ value: Any?) -> String? {
        if let number = value as? NSNumber { return number.stringValue }
        if let string = value as? String, !string.isEmpty, string.allSatisfy(\.isNumber) { return string }
        return nil
    }
}
