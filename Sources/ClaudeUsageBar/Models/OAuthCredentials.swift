import Foundation

/// OAuth state the Claude Code CLI writes to the macOS Keychain
/// (service `Claude Code-credentials`) — the same JSON shape it writes to
/// `~/.claude/.credentials.json` on Linux.
struct OAuthCredentials: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Double
    let subscriptionType: String?
    let rateLimitTier: String?

    var isExpired: Bool {
        expiresAt / 1000.0 <= Date().timeIntervalSince1970
    }

    /// Human-readable plan label, e.g. "Pro", "Max 5x", "Max 20x".
    var planLabel: String {
        guard let sub = subscriptionType, !sub.isEmpty else { return L10n.planUnknown }
        var label = sub.prefix(1).uppercased() + sub.dropFirst()
        if let tier = rateLimitTier {
            if tier.contains("20x") { label += " 20x" }
            else if tier.contains("5x") { label += " 5x" }
        }
        return label
    }

    /// A copy with the access token (and, if rotated, refresh token) swapped
    /// in from a token-refresh response. Never persisted by the caller —
    /// see `AnthropicUsageAPI.refreshAccessToken`.
    func refreshed(with response: RefreshResponse) -> OAuthCredentials {
        OAuthCredentials(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? refreshToken,
            expiresAt: (Date().timeIntervalSince1970 + response.expiresIn) * 1000,
            subscriptionType: subscriptionType,
            rateLimitTier: rateLimitTier
        )
    }
}

/// Wrapper matching the on-disk / Keychain JSON: `{ "claudeAiOauth": {...} }`.
struct CredentialsFile: Decodable {
    let claudeAiOauth: OAuthCredentials
}

/// Response from `POST /v1/oauth/token` (refresh grant).
struct RefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Double
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}
