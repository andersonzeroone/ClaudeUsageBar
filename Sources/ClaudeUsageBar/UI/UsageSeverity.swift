import AppKit

/// Maps a usage percentage to the same four-tier severity scale used across
/// the UI (progress bar fill color today; the menu bar icon's own
/// red-at-critical threshold in `MenuBarIcon` is a coarser one-bit version
/// of this).
enum UsageSeverity {
    static func color(for pct: Int) -> NSColor {
        switch pct {
        case ..<50: return .systemGreen
        case 50..<75: return .systemYellow
        case 75..<90: return .systemOrange
        default: return .systemRed
        }
    }
}
