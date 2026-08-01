import Cocoa
import Foundation

// MARK: - Models

private struct ClaudeAccount: Decodable {
    let emailAddress: String?
    let displayName: String?
    let organizationName: String?
    let organizationType: String?
    let organizationRole: String?
}

private struct ClaudeDotJSON: Decodable {
    let oauthAccount: ClaudeAccount?
}

private struct OauthCreds: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Double
    let subscriptionType: String?
    let rateLimitTier: String?
}

private struct CredentialsFile: Decodable {
    let claudeAiOauth: OauthCreds
}

private struct UsageWindow: Decodable {
    let utilization: Double?
    let resetsAt: String?
    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

private struct UsageResponse: Decodable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

private struct RefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Double
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

// MARK: - Constants

private enum API {
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let tokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let betaHeader = "oauth-2025-04-20"
    // The usage endpoint rate-limits hard without a claude-code User-Agent.
    static let fallbackUserAgent = "claude-code/2.1.197"
    static let keychainService = "Claude Code-credentials"
}

// MARK: - Data sources (read-only: never writes to Keychain or ~/.claude.json)

private enum DataSource {
    static func readAccountInfo() -> ClaudeAccount? {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".claude.json")
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(ClaudeDotJSON.self, from: data).oauthAccount
    }

    static func readKeychainCredentials() -> CredentialsFile? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-s", API.keychainService, "-w"]
        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            guard let jsonString = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                let jsonData = jsonString.data(using: .utf8)
            else { return nil }
            return try? JSONDecoder().decode(CredentialsFile.self, from: jsonData)
        } catch {
            return nil
        }
    }

    static func cliUserAgent() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["claude", "--version"]
        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8) else { return API.fallbackUserAgent }
            // Typical output: "2.1.197 (Claude Code)"
            if let versionToken = text.split(separator: " ").first,
               versionToken.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil {
                return "claude-code/\(versionToken)"
            }
            return API.fallbackUserAgent
        } catch {
            return API.fallbackUserAgent
        }
    }

    static func fetchUsage(accessToken: String, userAgent: String) async -> Result<UsageResponse, FetchError> {
        var request = URLRequest(url: API.usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(API.betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure(.transport) }
            if http.statusCode == 401 {
                return .failure(.unauthorized)
            }
            guard (200...299).contains(http.statusCode) else { return .failure(.http(http.statusCode)) }
            let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
            return .success(usage)
        } catch {
            return .failure(.transport)
        }
    }

    /// Best-effort, in-memory refresh only — the rotated token is never
    /// written back to the Keychain, so this app never mutates Claude Code's
    /// own credential state.
    static func refreshAccessToken(refreshToken: String) async -> RefreshResponse? {
        var request = URLRequest(url: API.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(API.betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-cli/1.0", forHTTPHeaderField: "User-Agent")
        let body: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": API.clientID,
            "refresh_token": refreshToken,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(RefreshResponse.self, from: data)
        } catch {
            return nil
        }
    }
}

private enum FetchError: Error {
    case notLoggedIn
    case unauthorized
    case http(Int)
    case transport
}

// MARK: - Formatting helpers

private enum Fmt {
    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso: ISO8601DateFormatter = ISO8601DateFormatter()
    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static func parseDate(_ s: String?) -> Date? {
        guard let s = s else { return nil }
        return isoFrac.date(from: s) ?? iso.date(from: s)
    }

    static func percent(_ raw: Double?) -> Int? {
        guard let raw = raw else { return nil }
        let pct = raw <= 1.0 ? raw * 100 : raw
        return Int(pct.rounded())
    }

    static func resetDescription(_ s: String?) -> String {
        guard let date = parseDate(s) else { return "—" }
        let now = Date()
        if date <= now { return "agora" }
        let interval = date.timeIntervalSince(now)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let relative: String
        if hours >= 24 {
            relative = "em \(hours / 24)d"
        } else if hours > 0 {
            relative = "em \(hours)h\(minutes)m"
        } else {
            relative = "em \(minutes)m"
        }
        return "\(relative) (às \(clock.string(from: date)))"
    }

    static func bar(_ pct: Int, width: Int = 12) -> String {
        let filled = max(0, min(width, Int((Double(pct) / 100.0 * Double(width)).rounded())))
        return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
    }

    static let updatedAt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}

// MARK: - Menu bar icon

/// Native SF Symbol gauge: the needle position tracks the 5h usage fraction
/// (macOS 13+), the same idiom macOS itself uses for the battery icon —
/// including turning red instead of adapting to the menu bar tint once
/// usage is critical.
private enum Icon {
    static func usageGauge(pct: Int) -> NSImage? {
        gauge(fraction: Double(pct) / 100.0, critical: pct >= 90)
    }

    static func loading() -> NSImage? {
        gauge(fraction: 0, critical: false)
    }

    static func warning() -> NSImage? {
        guard let base = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Aviso") else { return nil }
        let config = NSImage.SymbolConfiguration(pointSize: NSFont.systemFontSize, weight: .medium)
        let image = base.withSymbolConfiguration(config) ?? base
        image.isTemplate = true
        return image
    }

    private static func gauge(fraction: Double, critical: Bool) -> NSImage? {
        let clamped = max(0.0, min(1.0, fraction))
        let base: NSImage?
        if #available(macOS 13.0, *) {
            base = NSImage(systemSymbolName: "gauge.with.needle", variableValue: clamped, accessibilityDescription: "Uso Claude")
        } else {
            base = NSImage(systemSymbolName: "gauge.with.needle", accessibilityDescription: "Uso Claude")
        }
        guard let base = base else { return nil }
        var config = NSImage.SymbolConfiguration(pointSize: NSFont.systemFontSize, weight: .medium)
        if critical {
            config = config.applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.systemRed]))
        }
        let image = base.withSymbolConfiguration(config) ?? base
        image.isTemplate = !critical
        return image
    }
}

// MARK: - App state / menu bar controller

@MainActor
private final class AppState: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var timer: Timer?
    private var userAgent = API.fallbackUserAgent
    private var isRefreshing = false

    override init() {
        super.init()
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.image = Icon.loading()
        statusItem.button?.title = " …"
        statusItem.menu = buildMenu(loading: true)

        Task {
            self.userAgent = DataSource.cliUserAgent()
            await self.refresh()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    @objc private func refreshNow() {
        Task { await refresh() }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let account = DataSource.readAccountInfo()

        guard let credsFile = DataSource.readKeychainCredentials() else {
            statusItem.button?.image = Icon.warning()
            statusItem.button?.title = " —"
            statusItem.menu = buildMenu(loading: false, account: account, error: "Não foi possível ler as credenciais no Keychain. Rode `claude` no Terminal para entrar.")
            return
        }
        var creds = credsFile.claudeAiOauth

        let expired = creds.expiresAt / 1000.0 <= Date().timeIntervalSince1970
        if expired && !creds.refreshToken.isEmpty {
            if let refreshed = await DataSource.refreshAccessToken(refreshToken: creds.refreshToken) {
                creds = OauthCreds(
                    accessToken: refreshed.accessToken,
                    refreshToken: refreshed.refreshToken ?? creds.refreshToken,
                    expiresAt: (Date().timeIntervalSince1970 + refreshed.expiresIn) * 1000,
                    subscriptionType: creds.subscriptionType,
                    rateLimitTier: creds.rateLimitTier
                )
            }
        }

        let result = await DataSource.fetchUsage(accessToken: creds.accessToken, userAgent: userAgent)
        switch result {
        case .success(let usage):
            let fiveHourPct = Fmt.percent(usage.fiveHour?.utilization) ?? 0
            statusItem.button?.image = Icon.usageGauge(pct: fiveHourPct)
            statusItem.button?.title = " \(fiveHourPct)%"
            statusItem.menu = buildMenu(loading: false, account: account, creds: creds, usage: usage)
        case .failure(.unauthorized):
            statusItem.button?.image = Icon.warning()
            statusItem.button?.title = " —"
            statusItem.menu = buildMenu(loading: false, account: account, error: "Sessão expirada. Rode `claude` no Terminal para reautenticar.")
        case .failure:
            statusItem.button?.image = Icon.warning()
            statusItem.button?.title = " —"
            statusItem.menu = buildMenu(loading: false, account: account, error: "Falha ao consultar o uso (rede ou API indisponível). Tentando novamente em breve.")
        }
    }

    private func planLabel(_ creds: OauthCreds?) -> String {
        guard let creds = creds, let sub = creds.subscriptionType, !sub.isEmpty else { return "Desconhecido" }
        var label = sub.prefix(1).uppercased() + sub.dropFirst()
        if let tier = creds.rateLimitTier {
            if tier.contains("20x") { label += " 20x" }
            else if tier.contains("5x") { label += " 5x" }
        }
        return label
    }

    private func buildMenu(
        loading: Bool,
        account: ClaudeAccount? = nil,
        creds: OauthCreds? = nil,
        usage: UsageResponse? = nil,
        error: String? = nil
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

        // Identity
        if let account = account {
            let name = account.displayName ?? "Conta Claude"
            addDisabled(name, bold: true)
            if let email = account.emailAddress {
                addDisabled(email)
            }
            if let org = account.organizationName {
                addDisabled("Org: \(org)")
            }
        } else {
            addDisabled("Conta não identificada", bold: true)
            addDisabled("(sem ~/.claude.json legível)")
        }
        addDisabled("Plano: \(planLabel(creds))")
        menu.addItem(.separator())

        if loading {
            addDisabled("Carregando uso…")
        } else if let error = error {
            addDisabled("⚠️ \(error)")
        } else if let usage = usage {
            let fivePct = Fmt.percent(usage.fiveHour?.utilization) ?? 0
            let sevenPct = Fmt.percent(usage.sevenDay?.utilization) ?? 0
            addDisabled("Sessão (5h)  \(Fmt.bar(fivePct))  \(fivePct)%")
            addDisabled("  reseta \(Fmt.resetDescription(usage.fiveHour?.resetsAt))")
            menu.addItem(.separator())
            addDisabled("Semana (7d)  \(Fmt.bar(sevenPct))  \(sevenPct)%")
            addDisabled("  reseta \(Fmt.resetDescription(usage.sevenDay?.resetsAt))")
        } else {
            addDisabled("Sem dados de uso.")
        }

        menu.addItem(.separator())
        addDisabled("Atualizado às \(Fmt.updatedAt.string(from: Date()))")
        let refreshItem = NSMenuItem(title: "Atualizar agora", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Sair", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }
}

// MARK: - Entry point

@main
final class AppMain: NSObject, NSApplicationDelegate {
    private var state: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        state = AppState()
    }

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // no Dock icon, menu bar only
        let delegate = AppMain()
        app.delegate = delegate
        app.run()
    }
}
