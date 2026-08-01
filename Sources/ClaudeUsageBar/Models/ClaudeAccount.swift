import Foundation

/// The Claude Code CLI's local record of who is currently logged in,
/// read from `~/.claude.json` → `oauthAccount`.
struct ClaudeAccount: Decodable {
    let emailAddress: String?
    let displayName: String?
    let organizationName: String?
    let organizationType: String?
    let organizationRole: String?
}

/// Top-level shape of `~/.claude.json`. Only the field this app reads is
/// modeled — `Decodable` ignores every other key in that (much larger) file.
struct ClaudeDotJSON: Decodable {
    let oauthAccount: ClaudeAccount?
}
