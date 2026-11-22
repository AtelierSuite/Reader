import DeclaredAgeRange
import Foundation
import WebKit
#if canImport(UIKit)
import UIKit
public typealias AdultContentGatePresenter = UIViewController
#else
import AppKit
public typealias AdultContentGatePresenter = NSWindow
#endif

public nonisolated enum AdultSite: Sendable {
    case dlsite
    case fanza

    var cookieName: String {
        switch self {
        case .dlsite: "adultchecked"
        case .fanza: "age_check_done"
        }
    }

    var cookieDomain: String {
        switch self {
        case .dlsite: ".dlsite.com"
        case .fanza: ".dmm.co.jp"
        }
    }

    var cookieLifetime: TimeInterval {
        switch self {
        case .dlsite: 60 * 60 * 24 * 730
        case .fanza: 60 * 60 * 24 * 30
        }
    }
}

public nonisolated enum AdultContentGateError: Error, Sendable {
    case underage
    case declined
    case unavailable
}

@MainActor
public enum AdultContentGate {

    public static func authorize(
        _ site: AdultSite,
        in dataStore: WKWebsiteDataStore,
        presenter: AdultContentGatePresenter
    ) async -> Result<Void, AdultContentGateError> {
        if await hasCookie(for: site, in: dataStore) {
            return .success(())
        }
        do {
            switch try await AgeRangeService.shared.requestAgeRange(ageGates: 18, in: presenter) {
            case .sharing(let range):
                guard let lowerBound = range.lowerBound, lowerBound >= 18 else {
                    return .failure(.underage)
                }
                await dataStore.httpCookieStore.setCookie(cookie(for: site))
                return .success(())
            case .declinedSharing:
                return .failure(.declined)
            @unknown default:
                return .failure(.unavailable)
            }
        } catch {
            return .failure(.unavailable)
        }
    }

    private static func hasCookie(for site: AdultSite, in dataStore: WKWebsiteDataStore) async -> Bool {
        let cookies = await dataStore.httpCookieStore.allCookies()
        return cookies.contains { cookie in
            cookie.name == site.cookieName
                && cookie.domain.lowercased().hasSuffix(site.cookieDomain.trimmingCharacters(in: ["."]))
                && (cookie.expiresDate ?? .distantFuture) > .now
        }
    }

    public nonisolated static func cookie(for site: AdultSite) -> HTTPCookie {
        HTTPCookie(properties: [
            .domain: site.cookieDomain,
            .path: "/",
            .name: site.cookieName,
            .value: "1",
            .expires: Date.now.addingTimeInterval(site.cookieLifetime)
        ])!
    }
}
