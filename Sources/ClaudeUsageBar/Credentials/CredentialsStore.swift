import Foundation

/// Reads the local, already-authenticated Claude Code state — the account
/// identity from `~/.claude.json` and the OAuth token from the macOS
/// Keychain. Read-only: never writes to either location.
enum CredentialsStore {
    private static let keychainService = "Claude Code-credentials"

    static func readAccount() -> ClaudeAccount? {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".claude.json")
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(ClaudeDotJSON.self, from: data).oauthAccount
    }

    static func readOAuthCredentials() -> OAuthCredentials? {
        guard let jsonData = readKeychainItem(service: keychainService) else { return nil }
        return try? JSONDecoder().decode(CredentialsFile.self, from: jsonData).claudeAiOauth
    }

    /// Shells out to the built-in `security(1)` tool rather than linking a
    /// Keychain framework — keeps the dependency graph at zero.
    private static func readKeychainItem(service: String) -> Data? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-s", service, "-w"]
        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            let raw = outPipe.fileHandleForReading.readDataToEndOfFile()
            guard let jsonString = String(data: raw, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            else { return nil }
            return jsonString.data(using: .utf8)
        } catch {
            return nil
        }
    }
}
