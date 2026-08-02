import AppKit

/// Why the last fetch didn't produce usable usage data — kept unlocalized so
/// the menu builder can translate it fresh on every render (including a
/// pure language switch with no new fetch), instead of freezing a message
/// string in whatever language was active when the error happened.
enum UsageErrorReason {
    case noKeychainCredentials
    case sessionExpired
    case fetchFailed

    var localizedMessage: String {
        switch self {
        case .noKeychainCredentials: return L10n.errorNoKeychain
        case .sessionExpired: return L10n.errorSessionExpired
        case .fetchFailed: return L10n.errorFetchFailed
        }
    }
}

/// Everything the dropdown menu needs to render one refresh cycle's worth of
/// state. A plain value type so `UsageMenuBuilder` stays a pure function of
/// its input.
struct MenuContent {
    var loading = false
    var account: ClaudeAccount?
    var credentials: OAuthCredentials?
    var usage: UsageResponse?
    var error: UsageErrorReason?
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
        ///
        /// Wraps instead of truncating, and grows the row to fit — long
        /// error messages or organization names would otherwise get cut off
        /// with an ellipsis at a fixed single-line height.
        func addLabel(_ attributed: NSAttributedString, minHeight: CGFloat = 20) {
            let contentWidth = rowWidth - rowIndent * 2
            let textHeight = ceil(attributed.boundingRect(
                with: NSSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            ).height)

            let label = NSTextField(labelWithAttributedString: attributed)
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 0
            label.preferredMaxLayoutWidth = contentWidth

            let height = max(minHeight, textHeight + 6)
            label.frame = NSRect(x: rowIndent, y: (height - textHeight) / 2, width: contentWidth, height: textHeight)
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
            addLabel(line, minHeight: 22)
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
            addPrimary("⚠️ \(error.localizedMessage)")
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
