import Foundation

extension InstagramProvider {
    private static let postsQueryDefaultsKey = "Instagram.PostsQuery"

    static var cachedPostsQuery: InstagramPostsQuery? {
        get {
            UserDefaults.standard.data(forKey: postsQueryDefaultsKey)
                .flatMap { try? JSONDecoder().decode(InstagramPostsQuery.self, from: $0) }
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: postsQueryDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: postsQueryDefaultsKey)
            }
        }
    }

    /// Instagram rotates the persisted query's doc_id, so read it from the
    /// profile page's JS bundles and keep it until a posts request fails.
    func resolvePostsQuery(profileHTML: String, session: URLSession) async -> InstagramPostsQuery {
        if let cachedPostsQuery = Self.cachedPostsQuery { return cachedPostsQuery }
        guard let discovered = await Self.discoverPostsQuery(profileHTML: profileHTML, session: session) else {
            log("InstagramProvider", "Posts query discovery failed, using fallback")
            return .fallback
        }
        // swiftlint:disable:next line_length
        log("InstagramProvider", "Discovered posts query doc_id=\(discovered.docID) providers=\(discovered.relayProviders.joined(separator: ","))")
        Self.cachedPostsQuery = discovered
        return discovered
    }

    @concurrent nonisolated static func discoverPostsQuery(
        profileHTML: String, session: URLSession
    ) async -> InstagramPostsQuery? {
        var docID = postsQueryDocID(in: profileHTML)
        var relayProviders = postsQueryRelayProviders(in: profileHTML)
        for scriptURL in scriptURLs(in: profileHTML) {
            if docID != nil, relayProviders != nil { break }
            var request = URLRequest(url: scriptURL, timeoutInterval: 30)
            request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
            guard let (data, _) = try? await session.data(for: request),
                  let script = String(data: data, encoding: .utf8) else { continue }
            docID = docID ?? postsQueryDocID(in: script)
            relayProviders = relayProviders ?? postsQueryRelayProviders(in: script)
        }
        guard let docID else { return nil }
        return InstagramPostsQuery(
            docID: docID,
            relayProviders: relayProviders ?? InstagramPostsQuery.fallback.relayProviders
        )
    }

    nonisolated static func scriptURLs(in html: String) -> [URL] {
        var seen = Set<String>()
        return matches(of: #"https://static\.cdninstagram\.com/rsrc\.php/[^"'\s\\]+\.js"#, in: html)
            .filter { seen.insert($0).inserted }
            .compactMap(URL.init(string:))
    }

    nonisolated static func postsQueryDocID(in script: String) -> String? {
        matches(
            of: #""PolarisProfilePostsQuery_instagramRelayOperation",\[\],\(function\([^)]*\)\{[^}]*?exports="(\d+)""#,
            in: script
        ).first
    }

    nonisolated static func postsQueryRelayProviders(in script: String) -> [String]? {
        guard let dependencies = matches(
            of: #"__d\("PolarisProfilePostsQuery\.graphql",\[([^\]]*)\]"#, in: script
        ).first else { return nil }
        return matches(of: #""([A-Za-z0-9_]+)\.relayprovider""#, in: dependencies)
    }

    /// Returns the first capture group of each match, or the whole match when there is none.
    private nonisolated static func matches(of pattern: String, in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            let captureRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
            return Range(captureRange, in: text).map { String(text[$0]) }
        }
    }
}
