import AppKit

/// The app icon you've picked in the menu. Wind-up teeth on cream is the built-in Liquid Glass one; the rest are
/// pictures in Resources/Icons, set as a custom icon on Yap.app the way pasting one in Finder's Get Info does.
enum AppIcon: String, CaseIterable {
    case cream, plum, teal, gob, endless, quote, silver, ribbon, bubble

    var title: String {
        switch self {
        case .cream: "Wind-up, cream"
        case .plum: "Wind-up, plum"
        case .teal: "Wind-up, teal"
        case .gob: "Gob"
        case .endless: "Endless yap"
        case .quote: "Quotes"
        case .silver: "Silver bubble"
        case .ribbon: "Ribbon"
        case .bubble: "Classic bubble"
        }
    }

    static var chosen: AppIcon { AppIcon(rawValue: UserDefaults.standard.string(forKey: "appIcon") ?? "") ?? .cream }
    private static var applied: AppIcon?

    /// Sets the chosen icon if it isn't already; an update replaces the app and loses a custom icon, so launch re-applies it.
    static func applyChosen() {
        let icon = chosen
        let path = Bundle.main.bundlePath
        let hasCustom = FileManager.default.fileExists(atPath: path + "/Icon\r")
        guard icon != applied || (icon != .cream) != hasCustom else { return }
        applied = icon
        let image = icon == .cream ? nil
            : Bundle.main.url(forResource: icon.rawValue, withExtension: "png", subdirectory: "Icons").flatMap(NSImage.init(contentsOf:))
        NSWorkspace.shared.setIcon(image, forFile: path, options: [])
        NSApp.applicationIconImage = image // nil puts the bundle's own back, for Sparkle's window and alerts
    }
}

/// How see-through the panel's glass is.
enum Glass: String, CaseIterable {
    case clear, frosted, smoky

    var title: String { rawValue.capitalized }
    /// Smoke at the top and bottom of the panel, and the glass's own tint.
    var smoke: (top: Double, bottom: Double, tint: Double) {
        switch self {
        case .clear: (0.3, 0.1, 0.18)
        case .frosted: (0.55, 0.25, 0.35)
        case .smoky: (0.82, 0.46, 0.55)
        }
    }
}
