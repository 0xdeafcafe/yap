// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Yap",
    platforms: [.macOS("26.0")],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.0")],
    targets: [
        // Objective-C, to catch the exceptions AVAudioEngine throws.
        .target(name: "Catch"),
        .executableTarget(
            name: "Yap",
            dependencies: ["Catch", .product(name: "Sparkle", package: "Sparkle")],
            swiftSettings: [.swiftLanguageMode(.v5)],
            // Sparkle.framework ships inside the app, next to the binary's folder.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
    ]
)
