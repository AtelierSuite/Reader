import Foundation
import SwiftSoup

nonisolated extension PetalAgentWorkspace {

    static let outlineLineLimit = 220
    static let outlineDepthLimit = 14
    static let markupCharacterLimit = 2400
    static let collapsedTags: Set<String> = ["nav", "footer", "form", "select", "dialog"]

    static func outline(of document: Document) -> String {
        guard let body = document.body() else { return "The page has no body." }
        var lines: [String] = []
        appendOutline(of: body, depth: 0, repeatCount: 1, to: &lines)
        if lines.count >= outlineLineLimit {
            lines.append("… outline truncated; use select and inspect to look closer.")
        }
        return lines.joined(separator: "\n")
    }

    private static func appendOutline(
        of element: Element, depth: Int, repeatCount: Int, to lines: inout [String]
    ) {
        guard lines.count < outlineLineLimit, depth <= outlineDepthLimit else { return }
        var line = String(repeating: "  ", count: depth) + fingerprint(of: element)
        if repeatCount > 1 { line += " ×\(repeatCount)" }
        let tagName = element.tagName().lowercased()
        if collapsedTags.contains(tagName) || (tagName == "header" && depth == 1) {
            lines.append(line + " (collapsed)")
            return
        }
        let children = element.children().array()
        if children.isEmpty, let sample = textSample(of: element, limit: 50) {
            line += " \"\(sample)\""
        }
        lines.append(line)

        var index = 0
        while index < children.count {
            let child = children[index]
            let childFingerprint = fingerprint(of: child)
            var runLength = 1
            while index + runLength < children.count,
                  fingerprint(of: children[index + runLength]) == childFingerprint {
                runLength += 1
            }
            appendOutline(of: child, depth: depth + 1, repeatCount: runLength, to: &lines)
            index += runLength
        }
    }

    static func fingerprint(of element: Element) -> String {
        var result = element.tagName().lowercased()
        let identifier = element.id()
        if !identifier.isEmpty, identifier.count <= 24, !identifier.contains(where: \.isNumber) {
            result += "#\(identifier)"
        }
        let classNames = ((try? element.classNames()) ?? []).filter { !$0.isEmpty }.prefix(4)
        for className in classNames { result += ".\(className)" }
        return result
    }

    static func textSample(of element: Element, limit: Int) -> String? {
        let text = ((try? element.text()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return text.count > limit ? String(text.prefix(limit)) + "…" : text
    }

    static func describeMatches(for selector: String, in document: Document) -> String {
        guard let matches = try? document.select(selector) else {
            return "\"\(selector)\" is not a valid selector."
        }
        guard !matches.isEmpty() else { return "\"\(selector)\" matches 0 elements." }
        var lines = ["\"\(selector)\" matches \(matches.count) elements. Samples:"]
        for (index, element) in matches.array().prefix(3).enumerated() {
            let attributes = (element.getAttributes()?.asList() ?? [])
                .prefix(5)
                .map { "\($0.getKey())=\"\(truncated($0.getValue(), limit: 60))\"" }
                .joined(separator: " ")
            let sample = textSample(of: element, limit: 120) ?? ""
            lines.append("[\(index)] <\(element.tagName()) \(attributes)> \"\(sample)\"")
        }
        return lines.joined(separator: "\n")
    }

    static func markup(for selector: String, index: Int, in document: Document) -> String {
        guard let matches = try? document.select(selector) else {
            return "\"\(selector)\" is not a valid selector."
        }
        let elements = matches.array()
        guard elements.indices.contains(index) else {
            return "\"\(selector)\" matches \(elements.count) elements; index \(index) is out of range."
        }
        guard let copy = elements[index].copy() as? Element else { return "Could not read that element." }
        for element in (try? copy.getAllElements().array()) ?? [] {
            for attribute in element.getAttributes()?.asList() ?? [] where attribute.getValue().count > 80 {
                _ = try? element.attr(attribute.getKey(), truncated(attribute.getValue(), limit: 80))
            }
        }
        let outerHTML = (try? copy.outerHtml()) ?? ""
        return truncated(outerHTML, limit: markupCharacterLimit)
    }

    private static func truncated(_ text: String, limit: Int) -> String {
        text.count > limit ? String(text.prefix(limit)) + "…" : text
    }
}
