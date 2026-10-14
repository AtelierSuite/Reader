import Foundation

public nonisolated struct NextPageURLCollector {
    public let baseURL: URL
    public private(set) var urls: [URL] = []
    private var seen: Set<String> = []

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public mutating func add(_ href: String) {
        guard let resolved = URL(string: href, relativeTo: baseURL)?.absoluteURL,
              isContinuationOfBaseArticle(resolved) else { return }
        let absolute = resolved.absoluteString
        if seen.contains(absolute) { return }
        seen.insert(absolute)
        urls.append(resolved)
    }

    /// CMSes like Joomla mark "Next Article" links with `rel="next"`, so only
    /// links that extend the current article's path count as further pages.
    private func isContinuationOfBaseArticle(_ candidate: URL) -> Bool {
        guard Self.normalizedHost(of: candidate) == Self.normalizedHost(of: baseURL) else {
            return false
        }
        let basePath = Self.pathStem(of: baseURL)
        let candidatePath = Self.pathStem(of: candidate)
        guard candidatePath.hasPrefix(basePath) else { return false }
        let remainder = candidatePath.dropFirst(basePath.count)
        guard let separator = remainder.first else { return true }
        return "/-_.".contains(separator)
    }

    private static func normalizedHost(of url: URL) -> String {
        let host = (url.host ?? "").lowercased()
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private static func pathStem(of url: URL) -> String {
        var path = url.deletingPathExtension().path.lowercased()
        while path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }
}
