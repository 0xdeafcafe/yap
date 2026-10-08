import CoreGraphics

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
