import CoreGraphics
import Foundation
import Carbon

/// Swallows fn events for other apps. GlobeKey separately disables the system Globe action,
/// which can fire below this event tap. Needs Accessibility.
final class FnKey {
    /// fn went down (true) or up (false).
    var onChange: (Bool) -> Void = { _ in }
    /// Another key was pressed while fn was held, e.g. fn+← for Home.
    var onOtherKey: () -> Void = {}
    /// True consumes Escape while Yap has a recording to cancel.
    var onEscape: () -> Bool = { false }
    private var escapeHeld = false
    var isActive: Bool { tap != nil }

    private var tap: CFMachPort?
    private var fnDown = false

    /// Returns false until Accessibility has been granted.
    func install() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue) | CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
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
        if event.getIntegerValueField(.keyboardEventKeycode) == 53 {
            if type == .keyDown {
                if escapeHeld { return nil }
                if onEscape() { escapeHeld = true; return nil }
            } else if type == .keyUp, escapeHeld {
                escapeHeld = false
                return nil
            }
        }
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
    static func selfTest() {
        let keys = FnKey()
        var recording = true, cancels = 0
        keys.onEscape = {
            guard recording else { return false }
            recording = false; cancels += 1; return true
        }
        let down = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true)!
        let up = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false)!
        precondition(keys.handle(.keyDown, down) == nil)
        precondition(keys.handle(.keyDown, down) == nil, "repeat must stay consumed")
        precondition(keys.handle(.keyUp, up) == nil)
        precondition(cancels == 1)
        precondition(keys.handle(.keyDown, down) != nil, "idle Escape belongs to the typing app")
        precondition(keys.handle(.keyUp, up) != nil)
        print("escape routing self-test passed")
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
        // -1 means the key wasn't set: macOS's default.
        if now != 0, UserDefaults.standard.object(forKey: saved) == nil { UserDefaults.standard.set(now ?? -1, forKey: saved) }
        set(0)
    }

    static func restore() {
        guard let was = UserDefaults.standard.object(forKey: saved) as? Int else { return }
        // Don't overwrite a different choice the user made while Yap was running.
        if (CFPreferencesCopyAppValue(key, domain) as? Int) == 0 { set(was < 0 ? nil : was) }
        UserDefaults.standard.removeObject(forKey: saved)
    }

    /// This is the live setter imported by macOS Keyboard Settings. Writing preferences alone
    /// leaves existing processes with their cached Globe action. Resolve the private API safely.
    private static func updateLive(_ value: Int) -> Bool {
        typealias Update = @convention(c) (Int32) -> Void
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "TISUpdateFnUsageType") else { return false }
        unsafeBitCast(symbol, to: Update.self)(Int32(value))
        return true
    }

    private static func set(_ value: Int?) {
        // Call the live setter BEFORE storing the new preference, so it can observe the change.
        // The absent default is Emoji & Symbols; remove the explicit key again after restoring it.
        _ = updateLive(value ?? 2)
        CFPreferencesSetAppValue(key, value as CFNumber?, domain)
        CFPreferencesAppSynchronize(domain)
    }
}
