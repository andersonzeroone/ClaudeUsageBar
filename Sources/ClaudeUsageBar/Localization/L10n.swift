import Foundation

/// Hand-rolled string catalog for the app's two supported languages. This is
/// a plain executable (no `.app` bundle), so it sidesteps `.strings` files
/// and `Bundle.module` lookup in favor of a dictionary keyed by
/// `AppLanguage.current` — every string the UI shows lives here, nowhere
/// else in the codebase.
enum L10n {
    // MARK: Account / plan

    static var accountUnknownTitle: String { pick(pt: "Conta não identificada", en: "Unknown account") }
    static var accountUnknownDetail: String { pick(pt: "(sem ~/.claude.json legível)", en: "(~/.claude.json not readable)") }
    static var accountFallbackName: String { pick(pt: "Conta Claude", en: "Claude account") }
    static var planUnknown: String { pick(pt: "Desconhecido", en: "Unknown") }
    static func org(_ name: String) -> String { pick(pt: "Org: \(name)", en: "Org: \(name)") }
    static func plan(_ label: String) -> String { pick(pt: "Plano: \(label)", en: "Plan: \(label)") }

    // MARK: Usage

    static var loadingUsage: String { pick(pt: "Carregando uso…", en: "Loading usage…") }
    static var noUsageData: String { pick(pt: "Sem dados de uso.", en: "No usage data.") }
    static func sessionLine(bar: String, pct: Int) -> String {
        pick(pt: "Sessão (5h)  \(bar)  \(pct)%", en: "Session (5h)  \(bar)  \(pct)%")
    }
    static func weeklyLine(bar: String, pct: Int) -> String {
        pick(pt: "Semana (7d)  \(bar)  \(pct)%", en: "Weekly (7d)  \(bar)  \(pct)%")
    }
    static func resetsLine(_ description: String) -> String {
        pick(pt: "  reseta \(description)", en: "  resets \(description)")
    }
    static func updatedAt(_ time: String) -> String {
        pick(pt: "Atualizado às \(time)", en: "Updated at \(time)")
    }

    // MARK: Reset countdown (used by UsageFormatter)

    static var resetNow: String { pick(pt: "agora", en: "now") }
    static var resetUnknown: String { "—" }
    static func resetInDays(_ days: Int) -> String { pick(pt: "em \(days)d", en: "in \(days)d") }
    static func resetInHoursMinutes(_ hours: Int, _ minutes: Int) -> String {
        pick(pt: "em \(hours)h\(minutes)m", en: "in \(hours)h\(minutes)m")
    }
    static func resetInMinutes(_ minutes: Int) -> String { pick(pt: "em \(minutes)m", en: "in \(minutes)m") }
    static func resetAt(relative: String, clock: String) -> String {
        pick(pt: "\(relative) (às \(clock))", en: "\(relative) (at \(clock))")
    }

    // MARK: Menu chrome

    static var refreshNow: String { pick(pt: "Atualizar agora", en: "Refresh now") }
    static var quit: String { pick(pt: "Sair", en: "Quit") }
    static var languageMenuTitle: String { pick(pt: "Idioma", en: "Language") }

    // MARK: Errors

    static var errorNoKeychain: String {
        pick(
            pt: "Não foi possível ler as credenciais no Keychain. Rode `claude` no Terminal para entrar.",
            en: "Couldn't read credentials from the Keychain. Run `claude` in Terminal to log in."
        )
    }
    static var errorSessionExpired: String {
        pick(
            pt: "Sessão expirada. Rode `claude` no Terminal para reautenticar.",
            en: "Session expired. Run `claude` in Terminal to re-authenticate."
        )
    }
    static var errorFetchFailed: String {
        pick(
            pt: "Falha ao consultar o uso (rede ou API indisponível). Tentando novamente em breve.",
            en: "Couldn't fetch usage (network or API unavailable). Retrying shortly."
        )
    }

    // MARK: Accessibility

    static var iconAccessibilityUsage: String { pick(pt: "Uso Claude", en: "Claude usage") }
    static var iconAccessibilityWarning: String { pick(pt: "Aviso", en: "Warning") }

    private static func pick(pt: String, en: String) -> String {
        AppLanguage.current == .ptBR ? pt : en
    }
}
