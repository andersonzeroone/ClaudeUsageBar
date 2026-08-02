import Foundation

enum UsageFetchError: Error {
    case unauthorized
    case http(Int)
    case transport
}

/// Talks to the same (undocumented, but stable) `/api/oauth/usage` endpoint
/// the official `claude` CLI uses to report usage.
///
/// Deliberately does **not** call the OAuth token-refresh endpoint. Refresh
/// tokens rotate server-side the moment they're used, whether or not the
/// caller persists the new one — so even a "read-only, in-memory only"
/// refresh attempt invalidates the refresh token already sitting in the
/// Keychain, which the real `claude` CLI needs to stay logged in. This app
/// only ever reads the access token as-is; if it's expired, the UI shows a
/// "session expired, run `claude`" message instead of trying to fix it.
enum AnthropicUsageAPI {
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
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
}
