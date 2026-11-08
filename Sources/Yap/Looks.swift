import AppKit

/// Yap has one icon, the one in the bundle. Older versions let you pick another and set it as a custom icon on
/// Yap.app (the way pasting one in Finder's Get Info does); this takes such a leftover off, once.
enum AppIcon {
    static func clearCustom() {
        let path = Bundle.main.bundlePath
        UserDefaults.standard.removeObject(forKey: "appIcon")
        guard FileManager.default.fileExists(atPath: path + "/Icon\r") else { return }
        NSWorkspace.shared.setIcon(nil, forFile: path, options: [])
    }
}
