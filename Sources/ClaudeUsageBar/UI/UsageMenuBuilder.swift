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
        quitAction: Selector
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
            addDisabled(account.displayName ?? "Conta Claude", bold: true)
            if let email = account.emailAddress { addDisabled(email) }
            if let org = account.organizationName { addDisabled("Org: \(org)") }
        } else {
            addDisabled("Conta não identificada", bold: true)
            addDisabled("(sem ~/.claude.json legível)")
        }
        addDisabled("Plano: \(content.credentials?.planLabel ?? "Desconhecido")")
        menu.addItem(.separator())

        if content.loading {
            addDisabled("Carregando uso…")
        } else if let error = content.error {
            addDisabled("⚠️ \(error)")
        } else if let usage = content.usage {
            let fivePct = UsageFormatter.percent(usage.fiveHour?.utilization)
            let sevenPct = UsageFormatter.percent(usage.sevenDay?.utilization)
            addDisabled("Sessão (5h)  \(UsageFormatter.textBar(fivePct))  \(fivePct)%")
            addDisabled("  reseta \(UsageFormatter.resetDescription(usage.fiveHour?.resetsAt))")
            menu.addItem(.separator())
            addDisabled("Semana (7d)  \(UsageFormatter.textBar(sevenPct))  \(sevenPct)%")
            addDisabled("  reseta \(UsageFormatter.resetDescription(usage.sevenDay?.resetsAt))")
        } else {
            addDisabled("Sem dados de uso.")
        }

        menu.addItem(.separator())
        addDisabled("Atualizado às \(UsageFormatter.timestampFormat.string(from: Date()))")

        let refreshItem = NSMenuItem(title: "Atualizar agora", action: refreshAction, keyEquivalent: "r")
        refreshItem.target = target
        menu.addItem(refreshItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Sair", action: quitAction, keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }
}
