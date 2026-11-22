import AppKit
import Hanami

extension AdultContentGate {

    static func authorizeInForeground(feedURL: String) async -> Result<Void, AdultContentGateError> {
        await authorize(feedURL: feedURL, presenter: NSApp.keyWindow ?? NSApp.mainWindow)
    }
}
