import AppKit

/// Everything the dropdown menu needs to render one refresh cycle's worth of
/// state. A plain value type so `UsageMenuBuilder` stays a pure function of
/// its input.
struct MenuContent {
    var loading = false
    var account: ClaudeAccount?
    var credentials: OAuthCredentials?
    var usage: UsageResponse?
    var error: String?
}

/// Builds the `NSMenu` shown when the status item is clicked. Pure
/// presentation: it never touches the network or the Keychain itself.
enum UsageMenuBuilder {
    private static let rowWidth: CGFloat = 280
    private static let rowIndent: CGFloat = 14

    static func build(
        _ content: MenuContent,
        target: AnyObject,
        refreshAction: Selector,
        quitAction: Selector,
        languageAction: Selector
    ) -> NSMenu {
        let menu = NSMenu()

        /// Renders as a plain, custom `NSView` row instead of a disabled
        /// `NSMenuItem` title. A disabled item's text gets dimmed by AppKit
        /// itself regardless of any color set on it — the only reliable way
        /// to get an exact color (for the secondary/tertiary hierarchy, or
        /// the severity-colored progress bar) is to draw it ourselves.
        func addLabel(_ attributed: NSAttributedString, height: CGFloat = 20) {
            let label = NSTextField(labelWithAttributedString: attributed)
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.frame = NSRect(x: rowIndent, y: (height - 16) / 2, width: rowWidth - rowIndent * 2, height: 16)
            let container = NSView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
            container.addSubview(label)
            let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.view = container
            menu.addItem(item)
        }

        func addPrimary(_ text: String, bold: Bool = false) {
            addLabel(NSAttributedString(string: text, attributes: [
                .font: bold ? NSFont.boldSystemFont(ofSize: 13) : NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
            ]))
        }

        func addSecondary(_ text: String) {
            addLabel(NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]))
        }

        /// A usage row with a two-tone, severity-colored progress bar.
        func addUsageLine(label: String, pct: Int) {
            let (filled, empty) = UsageFormatter.textBarComponents(pct)
            let barFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            let line = NSMutableAttributedString(string: "\(label)  ", attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
            ])
            line.append(NSAttributedString(string: filled, attributes: [
                .font: barFont,
                .foregroundColor: UsageSeverity.color(for: pct),
            ]))
            line.append(NSAttributedString(string: empty, attributes: [
                .font: barFont,
                .foregroundColor: NSColor.tertiaryLabelColor,
            ]))
            line.append(NSAttributedString(string: "  \(pct)%", attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ]))
            addLabel(line, height: 22)
        }

        if let account = content.account {
            addPrimary(account.displayName ?? L10n.accountFallbackName, bold: true)
            if let email = account.emailAddress { addSecondary(email) }
            if let org = account.organizationName { addSecondary(L10n.org(org)) }
        } else {
            addPrimary(L10n.accountUnknownTitle, bold: true)
            addSecondary(L10n.accountUnknownDetail)
        }
        addSecondary(L10n.plan(content.credentials?.planLabel ?? L10n.planUnknown))
        menu.addItem(.separator())

        if content.loading {
            addSecondary(L10n.loadingUsage)
        } else if let error = content.error {
            addPrimary("⚠️ \(error)")
        } else if let usage = content.usage {
            let fivePct = UsageFormatter.percent(usage.fiveHour?.utilization)
            let sevenPct = UsageFormatter.percent(usage.sevenDay?.utilization)
            addUsageLine(label: L10n.sessionLabel, pct: fivePct)
            addSecondary(L10n.resetsLine(UsageFormatter.resetDescription(usage.fiveHour?.resetsAt)))
            menu.addItem(.separator())
            addUsageLine(label: L10n.weeklyLabel, pct: sevenPct)
            addSecondary(L10n.resetsLine(UsageFormatter.resetDescription(usage.sevenDay?.resetsAt)))
        } else {
            addSecondary(L10n.noUsageData)
        }

        menu.addItem(.separator())
        addSecondary(L10n.updatedAt(UsageFormatter.timestampFormat.string(from: Date())))

        let languageItem = NSMenuItem(title: L10n.languageMenuTitle, action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for language in AppLanguage.allCases {
            let item = NSMenuItem(title: language.displayName, action: languageAction, keyEquivalent: "")
            item.target = target
            item.representedObject = language
            item.state = (language == AppLanguage.current) ? .on : .off
            languageMenu.addItem(item)
        }
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        let refreshItem = NSMenuItem(title: L10n.refreshNow, action: refreshAction, keyEquivalent: "r")
        refreshItem.target = target
        menu.addItem(refreshItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: L10n.quit, action: quitAction, keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }
}
