import SwiftUI
import Hanami

/// Localized greeting + sentence terminator for the Today section header.
struct TodayGreeting {
    let text: String
    let terminator: String

    static func from(date: Date) -> TodayGreeting {
        let hour = Calendar.current.component(.hour, from: date)
        let key: String
        switch hour {
        case 5..<12: key = "TodayGreeting.Morning"
        case 12..<18: key = "TodayGreeting.Afternoon"
        case 18..<21: key = "TodayGreeting.EarlyEvening"
        case 21..<24: key = "TodayGreeting.Evening"
        default: key = "TodayGreeting.LateNight"
        }
        let body = String(localized: String.LocalizationValue(key), table: "Home")
        let terminator = String(localized: "TodayGreeting.Period", table: "Home")
        return TodayGreeting(text: body, terminator: terminator)
    }
}
