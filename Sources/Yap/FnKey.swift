import CoreGraphics
import Foundation

/// Takes the fn key over from macOS. An event tap swallows fn presses, so the system never sees
/// them and never opens the emoji picker or starts its own dictation. Needs Accessibility.
final class FnKey {
    /// fn went down (true) or up (false).
    var onChange: (Bool) -> Void = { _ in }
    /// Another key was pressed while fn was held, e.g. fn+← for Home.
    var onOtherKey: () -> Void = {}
    var isActive: Bool { tap != nil }

    private var tap: CFMachPort?
    private var fnDown = false

    /// Returns false until Accessibility has been granted.
    func install() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue) | CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
            callback: { _, type, event, me in Unmanaged<FnKey>.fromOpaque(me!).takeUnretainedValue().handle(type, event) },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS switches a tap off if it's ever slow; switch it straight back on.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .keyDown where fnDown:
            onOtherKey()
        case .flagsChanged where event.getIntegerValueField(.keyboardEventKeycode) == 63: // kVK_Function
            fnDown = event.flags.contains(.maskSecondaryFn)
            onChange(fnDown)
            return nil
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }
}

/// macOS acts on 🌐 (fn) below where an event tap reaches, so swallowing the key doesn't stop the emoji
/// picker. Instead Yap sets System Settings › Keyboard › "Press 🌐 key to" to Do Nothing while it runs,
/// and puts yours back when it quits.
enum GlobeKey {
    private static let domain = "com.apple.HIToolbox" as CFString
    private static let key = "AppleFnUsageType" as CFString // 0 Do Nothing, 1 input source, 2 emoji, 3 dictation
    private static let saved = "globeKeyWas"

    static func silence() {
        let now = CFPreferencesCopyAppValue(key, domain) as? Int
        guard now != 0 else { return }
        // -1 means the key wasn't set: macOS's default.
        if UserDefaults.standard.object(forKey: saved) == nil { UserDefaults.standard.set(now ?? -1, forKey: saved) }
        set(0)
    }

    static func restore() {
        guard let was = UserDefaults.standard.object(forKey: saved) as? Int else { return }
        set(was < 0 ? nil : was)
        UserDefaults.standard.removeObject(forKey: saved)
    }

    private static func set(_ value: Int?) {
        CFPreferencesSetAppValue(key, value as CFNumber?, domain)
        CFPreferencesAppSynchronize(domain)
        // What System Settings sends when you change it there.
        DistributedNotificationCenter.default().postNotificationName(.init("com.apple.keyboard.fnstatedidchange"), object: nil, deliverImmediately: true)
    }
}
