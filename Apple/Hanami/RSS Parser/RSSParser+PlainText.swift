import Foundation

public nonisolated extension RSSParser {

    static func paragraphHTML(fromPlainText text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { paragraph in
                let escaped = escapeXMLText(paragraph).replacingOccurrences(of: "\n", with: "<br>")
                return "<p>\(escaped)</p>"
            }
            .joined()
    }
}
