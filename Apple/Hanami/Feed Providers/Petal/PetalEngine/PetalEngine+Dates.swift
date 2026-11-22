import Foundation

public nonisolated extension PetalEngine {

    // MARK: - Flexible date parsing

    /// Parses timestamps using ISO8601 and a handful of common fallback formats.
    static func parseFlexibleDate(_ raw: String) -> Date? {
        if let iso = isoFormatter.date(from: raw) {
            return iso
        }
        if let isoFractional = isoFractionalFormatter.date(from: raw) {
            return isoFractional
        }
        for formatter in fallbackDateFormatters {
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        return parseRelativeDate(raw)
    }

    /// Reads "3 hours ago", "yesterday" and "3時間前" as an offset from now.
    static func parseRelativeDate(_ raw: String, now: Date = Date()) -> Date? {
        let text = raw.lowercased()
        if text == "yesterday" || text == "昨日" { return now.addingTimeInterval(-86400) }
        if text == "today" || text == "just now" || text == "今日" { return now }
        guard let match = text.firstMatch(of: relativeDateRegex),
              let amount = Double(match.1) else { return nil }
        let unit = String(match.2)
        guard let seconds = relativeUnitSeconds.first(where: { unit.hasPrefix($0.prefix) })?.seconds else {
            return nil
        }
        return now.addingTimeInterval(-amount * seconds)
    }

    private static let relativeUnitSeconds: [(prefix: String, seconds: Double)] = [
        ("sec", 1), ("秒", 1), ("min", 60), ("分", 60), ("hour", 3600), ("hr", 3600), ("時間", 3600),
        ("day", 86400), ("日", 86400), ("week", 604_800), ("週間", 604_800),
        ("month", 2_592_000), ("か月", 2_592_000), ("ヶ月", 2_592_000), ("year", 31_536_000), ("年", 31_536_000)
    ]

    nonisolated(unsafe) private static let relativeDateRegex =
        /^(\d+)\s*(seconds?|secs?|minutes?|mins?|hours?|hrs?|days?|weeks?|months?|years?|秒|分|時間|日|週間|か月|ヶ月|年)\s*(?:ago|前)$/

    // MARK: - Formatter caches

    // Foundation date formatters are thread-safe for read-only use but not Sendable,
    // so `nonisolated(unsafe)` is used since these caches are never mutated after setup.

    nonisolated(unsafe) static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) static let isoFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let fallbackDateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "MMMM d, yyyy",
            "MMM d, yyyy",
            "d MMMM yyyy",
            "d MMM yyyy",
            "EEE, d MMM yyyy HH:mm:ss Z",
            "yyyy/M/d HH:mm",
            "yyyy/M/d",
            "yyyy.M.d",
            "yyyy年M月d日 HH:mm",
            "yyyy年M月d日",
            "yyyy년 M월 d일"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }()
}
