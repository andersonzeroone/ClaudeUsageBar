import AppKit

/// Owns the `NSStatusItem`, drives the 60s refresh timer, and wires fetched
/// state into `MenuBarIcon` / `UsageMenuBuilder`. The only type in the app
/// that mutates UI state.
@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var timer: Timer?
    private var userAgent = AnthropicUsageAPI.fallbackUserAgent
    private var isRefreshing = false

    /// Last rendered state, kept around so switching languages can redraw
    /// the menu instantly without a network round trip.
    private var currentIcon: NSImage?
    private var currentTitle = " …"
    private var currentContent = MenuContent(loading: true)

    override init() {
        super.init()
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        statusItem.button?.imagePosition = .imageLeading
        currentIcon = MenuBarIcon.loading()
        applyRender()

        Task {
            userAgent = ClaudeCLI.usageEndpointUserAgent(fallback: AnthropicUsageAPI.fallbackUserAgent)
            await refresh()
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

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let language = sender.representedObject as? AppLanguage, language != AppLanguage.current else { return }
        AppLanguage.current = language
        applyRender()
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let account = CredentialsStore.readAccount()

        guard let credentials = await resolveCredentials() else {
            render(
                icon: MenuBarIcon.warning(),
                title: " —",
                content: MenuContent(account: account, error: .noKeychainCredentials)
            )
            return
        }

        switch await AnthropicUsageAPI.fetchUsage(accessToken: credentials.accessToken, userAgent: userAgent) {
        case .success(let usage):
            let fiveHourPct = UsageFormatter.percent(usage.fiveHour?.utilization)
            render(
                icon: MenuBarIcon.usageGauge(percent: fiveHourPct),
                title: " \(fiveHourPct)%",
                content: MenuContent(account: account, credentials: credentials, usage: usage)
            )
        case .failure(.unauthorized):
            render(
                icon: MenuBarIcon.warning(),
                title: " —",
                content: MenuContent(account: account, credentials: credentials, error: .sessionExpired)
            )
        case .failure:
            render(
                icon: MenuBarIcon.warning(),
                title: " —",
                content: MenuContent(account: account, credentials: credentials, error: .fetchFailed)
            )
        }
    }

    /// Reads the Keychain credentials and, if the access token is expired
    /// and a refresh token exists, refreshes in memory only (never written
    /// back — see `AnthropicUsageAPI`).
    private func resolveCredentials() async -> OAuthCredentials? {
        guard let credentials = CredentialsStore.readOAuthCredentials() else { return nil }
        guard credentials.isExpired, !credentials.refreshToken.isEmpty else { return credentials }
        guard let refreshed = await AnthropicUsageAPI.refreshAccessToken(refreshToken: credentials.refreshToken) else {
            return credentials
        }
        return credentials.refreshed(with: refreshed)
    }

    private func render(icon: NSImage?, title: String, content: MenuContent) {
        currentIcon = icon
        currentTitle = title
        currentContent = content
        applyRender()
    }

    /// Redraws the status item and menu from the cached state — used both
    /// after a fresh fetch and after a plain language switch.
    private func applyRender() {
        statusItem.button?.image = currentIcon
        statusItem.button?.title = currentTitle
        statusItem.menu = UsageMenuBuilder.build(
            currentContent,
            target: self,
            refreshAction: #selector(refreshNow),
            quitAction: #selector(quit),
            languageAction: #selector(selectLanguage(_:))
        )
    }
}
