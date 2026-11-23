import SwiftUI
import Hanami

extension FeedSection {

    var providerTint: Color? {
        switch self {
        case .feeds, .podcasts: nil
        case .bluesky: Color(red: 0.07, green: 0.52, blue: 1.0)
        case .fediverse: Color(red: 0.55, green: 0.29, blue: 0.88)
        case .instagram: Color(red: 0.84, green: 0.16, blue: 0.46)
        case .reddit: Color(red: 1.0, green: 0.27, blue: 0.0)
        case .substack: Color(red: 1.0, green: 0.40, blue: 0.10)
        case .vimeo: Color(red: 0.10, green: 0.72, blue: 0.92)
        case .youtube: Color(red: 1.0, green: 0.0, blue: 0.0)
        case .dlsite: .adaptive(light: (0.02, 0.16, 0.51), dark: (0.36, 0.50, 0.84))
        case .hackerNews: Color(red: 1.0, green: 0.40, blue: 0.0)
        case .netflix: Color(red: 0.90, green: 0.04, blue: 0.08)
        case .pixiv: Color(red: 0.0, green: 0.59, blue: 0.98)
        case .qiita: Color(red: 0.33, green: 0.77, blue: 0.0)
        case .telegram: Color(red: 0.15, green: 0.65, blue: 0.89)
        case .tumblr: .adaptive(light: (0.21, 0.27, 0.36), dark: (0.49, 0.58, 0.72))
        case .zenn: Color(red: 0.24, green: 0.66, blue: 1.0)
        case .appStore: Color(red: 0.07, green: 0.56, blue: 0.98)
        case .playStore, .note, .x, .niconico, .dmm, .github: .primary
        }
    }

    var providerStyle: AnyShapeStyle? {
        switch self {
        case .fediverse:
            AnyShapeStyle(LinearGradient(
                colors: [.purple, .blue, .green, .yellow, .red],
                startPoint: .bottom,
                endPoint: .top
            ))
        case .instagram:
            AnyShapeStyle(LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.78, blue: 0.29),
                    Color(red: 0.98, green: 0.49, blue: 0.12),
                    Color(red: 0.84, green: 0.16, blue: 0.46),
                    Color(red: 0.59, green: 0.18, blue: 0.75)
                ],
                startPoint: .bottom,
                endPoint: .top
            ))
        default:
            providerTint.map { AnyShapeStyle($0) }
        }
    }

    var usesMulticolorProviderSymbol: Bool {
        self == .playStore
    }

    var providerTileTint: Color? {
        guard let providerTint, providerTint != .primary else { return nil }
        return providerTint.opacity(0.2)
    }
}

private extension Color {
    static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        #if canImport(UIKit)
        Color(UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
        #else
        Color(NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
        #endif
    }
}
