import Foundation
import Hanami
import WebKit

/// YouTube overlays a consent dialog on the player for EU visitors unless the
/// web view's store already holds a `SOCS` cookie when the page loads.
enum YouTubeConsentCookie {

    static func ensure(in store: WKWebsiteDataStore) async {
        let cookieStore = store.httpCookieStore
        let cookies = await cookieStore.allCookies()
        let hasConsentChoice = cookies.contains { cookie in
            cookie.name == consentName
                && cookie.domain.lowercased().hasSuffix("youtube.com")
                && !cookie.value.hasPrefix("CAA")
        }
        guard !hasConsentChoice, let cookie = consentCookie() else { return }
        await cookieStore.setCookie(cookie)
    }

    private static var consentName: String {
        String(youTubeConsentCookie.prefix { $0 != "=" })
    }

    private static func consentCookie() -> HTTPCookie? {
        let value = String(youTubeConsentCookie.drop { $0 != "=" }.dropFirst())
        return HTTPCookie(properties: [
            .domain: ".youtube.com",
            .path: "/",
            .name: consentName,
            .value: value,
            .secure: "TRUE",
            .expires: Date.now.addingTimeInterval(60 * 60 * 24 * 365)
        ])
    }
}
