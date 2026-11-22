import Hanami
import UIKit
import WebKit

@MainActor
enum AdultFeedAuthorization {

    /// The reason the feed can't be added, or `nil` when it can.
    static func denialMessage(forFeedURL feedURL: String) async -> String? {
        guard let site = AdultFeedSites.site(forFeedURL: feedURL) else { return nil }
        guard let presenter = topViewController() else { return AdultContentGateError.unavailable.message }
        switch await AdultContentGate.authorize(site, in: .default(), presenter: presenter) {
        case .success: return nil
        case .failure(let error): return error.message
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var controller = scene?.keyWindow?.rootViewController
        while let presented = controller?.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }
}
