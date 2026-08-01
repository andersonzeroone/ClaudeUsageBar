import Foundation

/// Small shell-out helper for details only the installed `claude` CLI knows.
enum ClaudeCLI {
    /// Value to send as the usage endpoint's `User-Agent` header — it
    /// rate-limits hard unless the request looks like it came from the
    /// official CLI. Matching the installed version exactly isn't required,
    /// just being in the right ballpark.
    static func usageEndpointUserAgent(fallback: String) -> String {
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
            guard let text = String(data: data, encoding: .utf8) else { return fallback }
            // Typical output: "2.1.197 (Claude Code)"
            if let versionToken = text.split(separator: " ").first,
               versionToken.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil {
                return "claude-code/\(versionToken)"
            }
            return fallback
        } catch {
            return fallback
        }
    }
}
