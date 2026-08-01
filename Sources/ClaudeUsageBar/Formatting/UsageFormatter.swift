import Foundation

/// Pure, side-effect-free formatting helpers for percentages, reset
/// countdowns, and text progress bars. Kept separate from the UI layer so
/// they're trivially unit-testable.
enum UsageFormatter {
    private static let isoWithFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso = ISO8601DateFormatter()
    private static let clockFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    static let timestampFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    static func parseDate(_ isoString: String?) -> Date? {
        guard let isoString else { return nil }
        return isoWithFractionalSeconds.date(from: isoString) ?? iso.date(from: isoString)
    }

    /// The usage endpoint has been observed returning both a `0...100`
    /// integer percent and a `0...1` fraction across payloads — normalize.
    static func percent(_ raw: Double?) -> Int {
        guard let raw else { return 0 }
        let pct = raw <= 1.0 ? raw * 100 : raw
        return Int(pct.rounded())
    }

    static func resetDescription(_ isoString: String?) -> String {
        guard let date = parseDate(isoString) else { return L10n.resetUnknown }
        let now = Date()
        if date <= now { return L10n.resetNow }
        let interval = date.timeIntervalSince(now)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let relative: String
        if hours >= 24 {
            relative = L10n.resetInDays(hours / 24)
        } else if hours > 0 {
            relative = L10n.resetInHoursMinutes(hours, minutes)
        } else {
            relative = L10n.resetInMinutes(minutes)
        }
        return L10n.resetAt(relative: relative, clock: clockFormat.string(from: date))
    }

    static func textBar(_ pct: Int, width: Int = 12) -> String {
        let (filled, empty) = textBarComponents(pct, width: width)
        return filled + empty
    }

    /// Filled vs. empty glyph runs, split out so callers (the menu builder)
    /// can color each run separately instead of one flat string.
    static func textBarComponents(_ pct: Int, width: Int = 12) -> (filled: String, empty: String) {
        let filledCount = max(0, min(width, Int((Double(pct) / 100.0 * Double(width)).rounded())))
        return (String(repeating: "█", count: filledCount), String(repeating: "░", count: width - filledCount))
    }
}
