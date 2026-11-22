import Foundation
import SwiftSoup

nonisolated extension PetalAgentWorkspace {

    static let outlineLineLimit = 220
    static let outlineDepthLimit = 14
    static let mainElementMinimum = 30
    static let markupCharacterLimit = 2400
    static let collapsedTags: Set<String> = ["nav", "footer", "form", "select", "dialog"]

    static func outline(of document: Document) -> String {
        guard let body = document.body() else { return "The page has no body." }
        let root = outlineRoot(in: body)
        var lines: [String] = []
        if root !== body {
            lines.append("Only \(fingerprint(of: root)) is shown; the rest of the page is navigation and chrome.")
        }
        appendOutline(of: root, depth: 0, repeatCount: 1, to: &lines)
        if lines.count >= outlineLineLimit {
            lines.append("… outline truncated; use select and inspect to look closer.")
        }
        return lines.joined(separator: "\n")
    }

    private static func outlineRoot(in body: Element) -> Element {
        guard let main = try? body.select("main, [role=main]").first(),
              ((try? main.getAllElements().count) ?? 0) >= mainElementMinimum else { return body }
        return main
    }

    private static func appendOutline(
        of element: Element, depth: Int, repeatCount: Int, to lines: inout [String]
    ) {
        guard lines.count < outlineLineLimit, depth <= outlineDepthLimit else { return }
        var line = String(repeating: "  ", count: depth) + fingerprint(of: element) + attributeHint(for: element)
        if repeatCount > 1 { line += " ×\(repeatCount)" }
        let tagName = element.tagName().lowercased()
        if collapsedTags.contains(tagName) || (tagName == "header" && depth <= 1) {
            lines.append(line + " (collapsed)")
            return
        }
        let children = element.children().array()
        if children.isEmpty, let sample = textSample(of: element, limit: 50) {
            line += " \"\(sample)\""
        }
        lines.append(line)

        let shapes = children.map(shape(of:))
        var shapeCounts: [String: Int] = [:]
        for shape in shapes { shapeCounts[shape, default: 0] += 1 }
        var shownShapes = Set<String>()
        for (child, shape) in zip(children, shapes) where shownShapes.insert(shape).inserted {
            appendOutline(of: child, depth: depth + 1, repeatCount: shapeCounts[shape] ?? 1, to: &lines)
        }
    }

    /// Siblings with the same tag, classes and direct children are one repeating block, even when other rows sit between them.
    private static func shape(of element: Element) -> String {
        fingerprint(of: element) + ">" + element.children().array().map(fingerprint(of:)).joined(separator: ",")
    }

    static func fingerprint(of element: Element) -> String {
        var result = element.tagName().lowercased()
        let identifier = element.id()
        if isSelectorSafe(identifier), identifier.count <= 24, !identifier.contains(where: \.isNumber) {
            result += "#\(identifier)"
        }
        let classNames = ((try? element.classNames()) ?? []).filter(isSelectorSafe).prefix(3)
        for className in classNames { result += ".\(className)" }
        return result
    }

    /// Utility classes such as `md:hidden` or `w-[480px]` need escaping in a selector and say nothing about content.
    private static func isSelectorSafe(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first, CharacterSet.letters.contains(first) || first == "_" else {
            return false
        }
        return name.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }
    }

    private static func attributeHint(for element: Element) -> String {
        switch element.tagName().lowercased() {
        case "time":
            return element.hasAttr("datetime") ? "[datetime]" : ""
        case "img":
            let source = (try? element.attr("src")) ?? ""
            guard source.isEmpty || source.hasPrefix("data:") else { return "" }
            return PetalEngine.lazyImageAttributes.first(where: element.hasAttr).map { "[\($0)]" } ?? ""
        default:
            return ""
        }
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
                .filter { keptAttributes.contains($0.getKey().lowercased()) }
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
            simplifyAttributes(of: element)
        }
        let outerHTML = (try? copy.outerHtml()) ?? ""
        return truncated(outerHTML, limit: markupCharacterLimit)
    }

    private static let keptAttributes: Set<String> = [
        "class", "id", "href", "src", "srcset", "datetime", "title", "alt", "rel", "itemprop", "role"
    ]

    /// Leaves only what a selector or a field can use, so styling and framework attributes do not crowd the markup.
    private static func simplifyAttributes(of element: Element) {
        for attribute in element.getAttributes()?.asList() ?? [] {
            let name = attribute.getKey().lowercased()
            let isLazyImage = PetalEngine.lazyImageAttributes.contains(name)
            guard keptAttributes.contains(name) || isLazyImage else {
                _ = try? element.removeAttr(attribute.getKey())
                continue
            }
            if name == "class" {
                let classNames = attribute.getValue().split(whereSeparator: \.isWhitespace).map(String.init)
                    .filter(isSelectorSafe)
                if classNames.isEmpty {
                    _ = try? element.removeAttr(attribute.getKey())
                } else {
                    _ = try? element.attr(attribute.getKey(), classNames.joined(separator: " "))
                }
            } else if attribute.getValue().count > 80 {
                _ = try? element.attr(attribute.getKey(), truncated(attribute.getValue(), limit: 80))
            }
        }
    }

    private static func truncated(_ text: String, limit: Int) -> String {
        text.count > limit ? String(text.prefix(limit)) + "…" : text
    }
}
