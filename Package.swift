// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Yap",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(name: "Yap", swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
