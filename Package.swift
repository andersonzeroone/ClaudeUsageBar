// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageBar",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "ClaudeUsageBar"
        )
    ]
)
