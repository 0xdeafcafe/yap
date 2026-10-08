// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Yap",
    platforms: [.macOS("26.0")],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.0")],
    targets: [
        .executableTarget(
            name: "Yap",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            swiftSettings: [.swiftLanguageMode(.v5)],
            // Sparkle.framework ships inside the app, next to the binary's folder.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
    ]
)
