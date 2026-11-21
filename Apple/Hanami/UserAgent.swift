import Foundation

public nonisolated let sakuraUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5 Mobile/15E148 Safari/605.1.15"

/// YouTube redirects cookieless EU requests to a consent page. `SOCS` values
/// starting with `CAA` mean no choice was made and still get redirected.
public nonisolated let youTubeConsentCookie = "SOCS=CAI"

public nonisolated var sakuraAcceptLanguage: String {
    let preferred = Locale.preferredLanguages.prefix(5)
    guard !preferred.isEmpty else { return "en-US,en;q=0.9" }
    return preferred.enumerated().map { index, language in
        if index == 0 { return language }
        let quality = max(0.1, 1.0 - Double(index) * 0.1)
        return "\(language);q=\(String(format: "%.1f", quality))"
    }.joined(separator: ",")
}

public extension URLRequest {
    nonisolated static func sakura(
        url: URL,
        timeoutInterval: TimeInterval = 60
    ) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(sakuraAcceptLanguage, forHTTPHeaderField: "Accept-Language")
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        if let host = url.host,
           let scheme = url.scheme,
           let referer = URL(string: "\(scheme)://\(host)/") {
            request.setValue(referer.absoluteString,
                             forHTTPHeaderField: "Referer")
        }
        return request
    }

    /// Image-fetch variant that asks for image/* so origins like
    /// external-preview.redd.it don't serve an HTML wrapper page.
    nonisolated static func sakuraImage(
        url: URL,
        timeoutInterval: TimeInterval = 60
    ) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(
            "image/avif,image/webp,image/*,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        if let referer = imageReferer(for: url) {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        return request
    }

    /// Feed icons are fetched without extra headers, except from hosts that refuse hotlinked requests.
    nonisolated static func feedIcon(url: URL) -> URLRequest {
        requiredImageReferer(for: url) == nil ? URLRequest(url: url) : sakuraImage(url: url)
    }

    private nonisolated static func imageReferer(for url: URL) -> String? {
        if let required = requiredImageReferer(for: url) { return required }
        guard let host = url.host, let scheme = url.scheme else { return nil }
        return URL(string: "\(scheme)://\(host)/")?.absoluteString
    }

    private nonisolated static func requiredImageReferer(for url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        return host == "pximg.net" || host.hasSuffix(".pximg.net") ? "https://www.pixiv.net/" : nil
    }
}
