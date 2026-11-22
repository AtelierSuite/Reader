import Foundation

/// Release details GitHub's Atom feed leaves out: the prerelease flag and the downloadable assets.
public nonisolated enum GitHubReleases {

    struct Release: Decodable {
        let tagName: String
        let prerelease: Bool
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case prerelease, assets
            case tagName = "tag_name"
        }
    }

    struct Asset: Decodable {
        let name: String
        let size: Int64
        let downloadURL: String

        enum CodingKeys: String, CodingKey {
            case name, size
            case downloadURL = "browser_download_url"
        }
    }

    public static func isReleasesFeedURL(_ feedURL: String) -> Bool {
        URL(string: feedURL).flatMap(repositoryPath(fromFeedURL:)) != nil
    }

    public static func hidesPrereleasesKey(forFeedID feedID: Int64) -> String {
        "hidePrereleases-\(feedID)"
    }

    static func repositoryPath(fromFeedURL url: URL) -> String? {
        let components = url.pathComponents
        guard url.host?.lowercased() == "github.com", components.count == 4,
              components[3] == "releases.atom" else { return nil }
        return "\(components[1])/\(components[2])"
    }

    /// Unauthenticated calls are limited to 60 an hour, so a refusal leaves the feed as it came.
    static func fetch(repositoryPath: String) async -> [String: Release] {
        guard let url = URL(string: "https://api.github.com/repos/\(repositoryPath)/releases?per_page=15") else {
            return [:]
        }
        var request = URLRequest.sakura(url: url, timeoutInterval: 6)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let releases = try? JSONDecoder().decode([Release].self, from: data) else {
            log("FeedRefresh.RSS", "GitHub releases unavailable repository=\(repositoryPath)")
            return [:]
        }
        return Dictionary(releases.map { ($0.tagName, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func tagName(fromReleaseURL urlString: String) -> String? {
        guard let url = URL(string: urlString), let tagIndex = url.pathComponents.firstIndex(of: "tag"),
              tagIndex + 1 < url.pathComponents.count else { return nil }
        return url.pathComponents[(tagIndex + 1)...].joined(separator: "/")
    }

    static func assetsHTML(for assets: [Asset]) -> String {
        guard !assets.isEmpty else { return "" }
        let heading = RSSParser.escapeXMLText(String(localized: "GitHub.Assets", table: "Feeds"))
        // One paragraph with only the sizes linked: a long list of file links reads as navigation and is trimmed.
        let lines = assets.map { asset in
            let size = ByteCountFormatter.string(fromByteCount: asset.size, countStyle: .file)
            return "\(RSSParser.escapeXMLText(asset.name)) · "
                + "<a href=\"\(RSSParser.escapeXMLAttribute(asset.downloadURL))\">\(size)</a>"
        }
        return "<h3>\(heading)</h3><p>\(lines.joined(separator: "<br>"))</p>"
    }
}
