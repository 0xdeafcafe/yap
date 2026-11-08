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

    /// The picture for Settings: the bundle's own icon for cream, the variant's for the rest. Shrunk once to the
    /// 48 pt it's shown at: decoded at full size (512 and 1024 pixels) the nine took 16 MB to show 96 pixels each.
    @MainActor var preview: NSImage? {
        if let hit = Self.previews[self] { return hit }
        let image = autoreleasepool { () -> NSImage? in
            let full = self == .cream ? Bundle.main.image(forResource: "AppIcon")
                : Bundle.main.url(forResource: rawValue, withExtension: "png", subdirectory: "Icons").flatMap(NSImage.init(contentsOf:))
            return full.flatMap { Self.shrink($0, points: 48) }
        }
        Self.previews[self] = image
        return image
    }
    @MainActor private static var previews: [AppIcon: NSImage?] = [:]

    /// `image` drawn at `points`, at 2x, in its own colours; the original's let go.
    static func shrink(_ image: NSImage, points: CGFloat) -> NSImage? {
        let px = Int(points * 2)
        var rect = CGRect(x: 0, y: 0, width: px, height: px)
        guard let source = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return image }
        let space = source.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(source, in: CGRect(x: 0, y: 0, width: px, height: px))
        return ctx.makeImage().map { NSImage(cgImage: $0, size: NSSize(width: points, height: points)) } ?? image
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
