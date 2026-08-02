import Foundation

/// OAuth state the Claude Code CLI writes to the macOS Keychain
/// (service `Claude Code-credentials`) — the same JSON shape it writes to
/// `~/.claude/.credentials.json` on Linux.
struct OAuthCredentials: Decodable {
    let accessToken: String
    let subscriptionType: String?
    let rateLimitTier: String?

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
}

/// Wrapper matching the on-disk / Keychain JSON: `{ "claudeAiOauth": {...} }`.
struct CredentialsFile: Decodable {
    let claudeAiOauth: OAuthCredentials
}
