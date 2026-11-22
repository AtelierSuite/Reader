import Foundation

nonisolated enum ExcludedSites {

    static let storageKey = "Reading.ExcludedSites"

    static let defaultDomains = [
        "apps.apple.com",
        "itunes.apple.com",
        "music.apple.com",
        "podcasts.apple.com",
        "books.apple.com",
        "tv.apple.com",
        "maps.apple.com",
        "testflight.apple.com",
        "facetime.apple.com",
        "apple.news",
        "apple.co",
        "icloud.com"
    ]

    static var domains: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: storageKey) ?? defaultDomains
        }
        set {
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }

    static func contains(_ url: URL?) -> Bool {
        guard let host = url?.host()?.lowercased(), !host.isEmpty else { return false }
        return domains.contains { domain in
            host == domain || host.hasSuffix(".\(domain)")
        }
    }

    /// Accepts a bare domain or a pasted URL, returning its host.
    static func normalizedDomain(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var host = URL(string: withScheme)?.host(), host.contains(".") else { return nil }
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        return host
    }
}
