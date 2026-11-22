import Foundation

public nonisolated extension AdultContentGateError {

    var message: String {
        switch self {
        case .underage: String(localized: "AgeGate.Underage", table: "Feeds")
        case .declined: String(localized: "AgeGate.Declined", table: "Feeds")
        case .unavailable: String(localized: "AgeGate.Unavailable", table: "Feeds")
        }
    }
}
