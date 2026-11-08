// swift-tools-version:5.9
// HookLink: a Mac app that builds Ocarina of Time (Switch 2 Edition) for iPhone from the player's own dump, with nxnative.
import PackageDescription

let package = Package(
    name: "HookLink",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "HookLink", path: "Sources/HookLink")
    ]
)
