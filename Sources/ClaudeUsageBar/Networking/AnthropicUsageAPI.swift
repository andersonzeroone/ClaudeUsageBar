import Foundation

enum UsageFetchError: Error {
    case unauthorized
    case http(Int)
    case transport
}

/// Talks to the same (undocumented, but stable) OAuth endpoints the official
/// `claude` CLI uses to report and refresh usage. Never account-mutating.
enum AnthropicUsageAPI {
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let tokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!
    /// Public Claude Code CLI OAuth client id (PKCE flow, no client secret) —
    /// not a credential of its own.
    private static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private static let betaHeader = "oauth-2025-04-20"
    static let fallbackUserAgent = "claude-code/2.1.197"

    static func fetchUsage(accessToken: String, userAgent: String) async -> Result<UsageResponse, UsageFetchError> {
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure(.transport) }
            if http.statusCode == 401 { return .failure(.unauthorized) }
            guard (200...299).contains(http.statusCode) else { return .failure(.http(http.statusCode)) }
            return .success(try JSONDecoder().decode(UsageResponse.self, from: data))
        } catch {
            return .failure(.transport)
        }
    }

    /// Best-effort, in-memory refresh only — the caller decides whether to
    /// use the rotated token; nothing here ever touches disk or the Keychain.
    static func refreshAccessToken(refreshToken: String) async -> RefreshResponse? {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-cli/1.0", forHTTPHeaderField: "User-Agent")
        let body: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": clientID,
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
