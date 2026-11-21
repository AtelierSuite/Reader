import Foundation

extension PixivProvider: Authenticated {

    public nonisolated static let cookieStore = KeychainCookieStore(
        service: "com.tsubuzaki.SakuraRSS.PixivCookies"
    )

    public nonisolated static func cookieDomainMatches(_ domain: String) -> Bool {
        domain == "pixiv.net" || domain.hasSuffix(".pixiv.net")
    }

    public nonisolated static var sessionCookieNames: Set<String>? { ["PHPSESSID"] }

    public nonisolated static var cookieWarmURL: URL? { URL(string: "\(origin)/") }

    public nonisolated static var loginURL: URL? { URL(string: "https://accounts.pixiv.net/login") }

    public nonisolated static func hasSession() -> Bool {
        sessionCookies() != nil
    }

    /// Pixiv only returns R-18 works to a signed-in account that allows them in its viewing settings.
    public nonisolated static var includesRestrictedWorks: Bool {
        hasSession()
    }

    nonisolated static func sessionCookies() -> [HTTPCookie]? {
        guard let cookies = cookieStore.load() else { return nil }
        let liveCookies = cookies.filter { cookie in
            cookieDomainMatches(cookie.domain.lowercased()) && (cookie.expiresDate ?? .distantFuture) > Date()
        }
        guard liveCookies.contains(where: { $0.name == "PHPSESSID" && $0.value.contains("_") }) else {
            return nil
        }
        return liveCookies
    }

    nonisolated static func sessionCookieHeader() -> String? {
        guard let cookies = sessionCookies() else { return nil }
        return HTTPCookie.requestHeaderFields(with: cookies)["Cookie"]
    }
}
