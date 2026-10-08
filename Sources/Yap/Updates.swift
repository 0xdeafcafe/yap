import AppKit
import Sparkle

/// Sparkle checks the appcast on GitHub once a day. A new version opens Sparkle's window, brought to the
/// front since Yap has no window of its own; from there you install it, or tick to have it install itself.
/// Updates must be signed with the EdDSA key in your keychain that SUPublicEDKey in Info.plist matches.
final class Updates: NSObject, SPUStandardUserDriverDelegate {
    private(set) lazy var controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self)

    func start() { controller.startUpdater() }
    func check() { NSApp.activate(); controller.checkForUpdates(nil) }

    // A menu bar app's window would open behind whatever you're using, so bring it forward.
    var supportsGentleScheduledUpdateReminders: Bool { true }
    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if handleShowingUpdate { NSApp.activate() }
    }
}
