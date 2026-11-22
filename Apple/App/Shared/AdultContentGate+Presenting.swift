import Hanami
import UIKit

extension AdultContentGate {

    static func authorizeInForeground(feedURL: String) async -> Result<Void, AdultContentGateError> {
        await authorize(feedURL: feedURL, presenter: topmostViewController())
    }

    private static func topmostViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .sorted { first, _ in first.activationState == .foregroundActive }
            .flatMap(\.windows)
        var controller = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController
        while let presented = controller?.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }
}
