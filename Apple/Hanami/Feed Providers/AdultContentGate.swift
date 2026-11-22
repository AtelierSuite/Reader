import DeclaredAgeRange
import Foundation
import WebKit
#if os(macOS)
import AppKit
public typealias AdultContentGatePresenter = NSWindow
#else
import UIKit
public typealias AdultContentGatePresenter = UIViewController
#endif

public enum AdultSite: Sendable {
    case dlsite
    case fanza
}

public enum AdultContentGateError: Error, Sendable {
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
        let cookie = cookie(for: site)
        let cookies = await dataStore.httpCookieStore.allCookies()
        if cookies.contains(where: { matches($0, cookie) }) {
            return .success(())
        }
        let response: AgeRangeService.Response
        do {
            response = try await AgeRangeService.shared.requestAgeRange(ageGates: 18, in: presenter)
        } catch {
            return .failure(.unavailable)
        }
        switch response {
        case .declinedSharing:
            return .failure(.declined)
        case .sharing(let range):
            guard let lowerBound = range.lowerBound, lowerBound >= 18 else { return .failure(.underage) }
            await dataStore.httpCookieStore.setCookie(cookie)
            return .success(())
        @unknown default:
            return .failure(.unavailable)
        }
    }

    public nonisolated static func cookie(for site: AdultSite) -> HTTPCookie {
        let (name, domain, days): (String, String, Double) = switch site {
        case .dlsite: ("adultchecked", ".dlsite.com", 730)
        case .fanza: ("age_check_done", ".dmm.co.jp", 30)
        }
        return HTTPCookie(properties: [
            .domain: domain,
            .path: "/",
            .name: name,
            .value: "1",
            .expires: Date.now.addingTimeInterval(60 * 60 * 24 * days)
        ])!
    }

    private static func matches(_ stored: HTTPCookie, _ expected: HTTPCookie) -> Bool {
        stored.name == expected.name
            && stored.value == expected.value
            && stored.domain.lowercased().hasSuffix(expected.domain.trimmingCharacters(in: ["."]))
    }
}
