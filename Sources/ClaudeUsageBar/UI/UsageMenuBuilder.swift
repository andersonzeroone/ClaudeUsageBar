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
    static func build(
        _ content: MenuContent,
        target: AnyObject,
        refreshAction: Selector,
        quitAction: Selector,
        languageAction: Selector
    ) -> NSMenu {
        let menu = NSMenu()

        func addDisabled(_ title: String, bold: Bool = false) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            if bold {
                item.attributedTitle = NSAttributedString(
                    string: title,
                    attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]
                )
            }
            menu.addItem(item)
        }

        if let account = content.account {
            addDisabled(account.displayName ?? L10n.accountFallbackName, bold: true)
            if let email = account.emailAddress { addDisabled(email) }
            if let org = account.organizationName { addDisabled(L10n.org(org)) }
        } else {
            addDisabled(L10n.accountUnknownTitle, bold: true)
            addDisabled(L10n.accountUnknownDetail)
        }
        addDisabled(L10n.plan(content.credentials?.planLabel ?? L10n.planUnknown))
        menu.addItem(.separator())

        if content.loading {
            addDisabled(L10n.loadingUsage)
        } else if let error = content.error {
            addDisabled("⚠️ \(error)")
        } else if let usage = content.usage {
            let fivePct = UsageFormatter.percent(usage.fiveHour?.utilization)
            let sevenPct = UsageFormatter.percent(usage.sevenDay?.utilization)
            addDisabled(L10n.sessionLine(bar: UsageFormatter.textBar(fivePct), pct: fivePct))
            addDisabled(L10n.resetsLine(UsageFormatter.resetDescription(usage.fiveHour?.resetsAt)))
            menu.addItem(.separator())
            addDisabled(L10n.weeklyLine(bar: UsageFormatter.textBar(sevenPct), pct: sevenPct))
            addDisabled(L10n.resetsLine(UsageFormatter.resetDescription(usage.sevenDay?.resetsAt)))
        } else {
            addDisabled(L10n.noUsageData)
        }

        menu.addItem(.separator())
        addDisabled(L10n.updatedAt(UsageFormatter.timestampFormat.string(from: Date())))

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
