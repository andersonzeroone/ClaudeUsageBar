import AppKit

/// Builds the SF Symbol images shown in the status item. The gauge needle
/// tracks usage fraction (macOS 13+) the same way the system battery icon
/// tracks charge, including turning red instead of following the menu bar
/// tint once usage is critical.
enum MenuBarIcon {
    static func usageGauge(percent: Int) -> NSImage? {
        gauge(fraction: Double(percent) / 100.0, critical: percent >= 90)
    }

    static func loading() -> NSImage? {
        gauge(fraction: 0, critical: false)
    }

    static func warning() -> NSImage? {
        guard let base = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: L10n.iconAccessibilityWarning) else { return nil }
        let config = NSImage.SymbolConfiguration(pointSize: NSFont.systemFontSize, weight: .medium)
        let image = base.withSymbolConfiguration(config) ?? base
        image.isTemplate = true
        return image
    }

    private static func gauge(fraction: Double, critical: Bool) -> NSImage? {
        let clamped = max(0.0, min(1.0, fraction))
        let base: NSImage?
        if #available(macOS 13.0, *) {
            base = NSImage(systemSymbolName: "gauge.with.needle", variableValue: clamped, accessibilityDescription: L10n.iconAccessibilityUsage)
        } else {
            base = NSImage(systemSymbolName: "gauge.with.needle", accessibilityDescription: L10n.iconAccessibilityUsage)
        }
        guard let base else { return nil }
        var config = NSImage.SymbolConfiguration(pointSize: NSFont.systemFontSize, weight: .medium)
        if critical {
            config = config.applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.systemRed]))
        }
        let image = base.withSymbolConfiguration(config) ?? base
        image.isTemplate = !critical
        return image
    }
}
