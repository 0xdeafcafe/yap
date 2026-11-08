import AppKit

/// Where the text you're about to dictate will go, so the listening panel can sit by it the way macOS's own
/// dictation bubble does. Read through Accessibility: the focused field's insertion point, else a small field's
/// frame. Terminals and some Electron apps don't say, and then the panel stays at the blob.
enum Caret {
    /// Between the caret's line and the panel.
    static let gap: CGFloat = 6
    /// The window's clear margin around the glass, as `LiquidOutline` lays it out.
    static let margin: CGFloat = 10
    /// The glass seed before it grows: a dot centred on the caret.
    static let seed: CGFloat = 20
    /// The tallest the panel gets (six lines and its padding) plus the Pasted chip and its drip.
    static let room: CGFloat = 210
    /// The widest it gets: the panel, the orb's neck at its longest, and the orb.
    static let reach: CGFloat = 496 + 12 + 38
    /// Taller than this isn't a caret or a one-line field; it's an editor or a terminal's whole buffer.
    static let tallest: CGFloat = 120

    // MARK: Reading it

    /// The caret in Accessibility's coordinates (top left of the main display, y down), or nil.
    /// Call off the main thread; each call to the app gives up when `budget` runs out.
    nonisolated static func read(budget: TimeInterval = 0.08) -> CGRect? {
        guard AXIsProcessTrusted() else { return nil }
        let deadline = Date().addingTimeInterval(budget)
        func remaining() -> Float { Float(max(0.01, deadline.timeIntervalSinceNow)) }
        func get(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
            AXUIElementSetMessagingTimeout(e, remaining())
            var v: CFTypeRef?
            return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
        }
        func element(_ v: CFTypeRef?) -> AXUIElement? {
            guard let v, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
            return (v as! AXUIElement)
        }
        func ax(_ v: CFTypeRef?) -> AXValue? {
            guard let v, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
            return (v as! AXValue)
        }
        func rect(_ v: CFTypeRef?) -> CGRect? {
            var r = CGRect.zero; return ax(v).map { AXValueGetValue($0, .cgRect, &r) } == true ? r : nil
        }
        func range(_ v: CFTypeRef?) -> CFRange? {
            var r = CFRange(); return ax(v).map { AXValueGetValue($0, .cfRange, &r) } == true ? r : nil
        }
        func point(_ v: CFTypeRef?) -> CGPoint? {
            var p = CGPoint.zero; return ax(v).map { AXValueGetValue($0, .cgPoint, &p) } == true ? p : nil
        }
        func size(_ v: CFTypeRef?) -> CGSize? {
            var s = CGSize.zero; return ax(v).map { AXValueGetValue($0, .cgSize, &s) } == true ? s : nil
        }
        func bounds(_ field: AXUIElement, _ location: Int, _ length: Int) -> CGRect? {
            guard location >= 0, Date() < deadline else { return nil }
            var range = CFRange(location: location, length: length)
            guard let arg = AXValueCreate(.cfRange, &range) else { return nil }
            AXUIElementSetMessagingTimeout(field, remaining())
            var out: CFTypeRef?
            guard AXUIElementCopyParameterizedAttributeValue(field, kAXBoundsForRangeParameterizedAttribute as CFString, arg, &out) == .success
            else { return nil }
            return rect(out).flatMap(plausible)
        }

        let system = AXUIElementCreateSystemWide()
        guard let app = element(get(system, kAXFocusedApplicationAttribute)),
              let field = element(get(app, kAXFocusedUIElementAttribute)) else { return nil }
        if let range = range(get(field, kAXSelectedTextRangeAttribute)) {
            // Where the words go: the start of a selection (it's replaced) or the insertion point.
            let at = range.location
            if let r = bounds(field, at, 0) { return r }
            // Many apps answer nothing for an empty range, so measure a character either side instead.
            if at > 0, let r = bounds(field, at - 1, 1) { return CGRect(x: r.maxX, y: r.minY, width: 0, height: r.height) }
            if let r = bounds(field, at, 1) { return CGRect(x: r.minX, y: r.minY, width: 0, height: r.height) }
        }
        // No caret, but a field small enough that sitting below it is as good.
        guard let origin = point(get(field, kAXPositionAttribute)), let size = size(get(field, kAXSizeAttribute)) else { return nil }
        return plausible(CGRect(origin: origin, size: size))
    }

    /// Apps answer an unknown position with zero, an empty line with no height, and an editor with its whole view.
    nonisolated static func plausible(_ r: CGRect) -> CGRect? {
        guard r.origin.x.isFinite, r.origin.y.isFinite, r.height > 1, r.height <= tallest,
              r.width >= 0, r.width < 4000, r.origin != .zero else { return nil }
        return r
    }

    /// Reads the caret on another thread, giving up after `timeout` so a hung app never holds the panel up.
    static func find(timeout: TimeInterval = 0.1) async -> CGRect? {
        await withCheckedContinuation { (cont: CheckedContinuation<CGRect?, Never>) in
            let lock = NSLock(); var done = false
            func finish(_ r: CGRect?) { lock.lock(); defer { lock.unlock() }; if !done { done = true; cont.resume(returning: r) } }
            DispatchQueue.global(qos: .userInteractive).async { finish(read()) }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }
    }

    // MARK: Placing the panel

    /// Accessibility measures from the top of the main display, y down; AppKit from its bottom, y up.
    static func flip(_ r: CGRect, mainHeight: CGFloat) -> CGRect {
        CGRect(x: r.minX, y: mainHeight - r.maxY, width: r.width, height: r.height)
    }

    /// The visible frame of the display the caret's on, or nearest to; nil if it's nowhere near one (a stale answer).
    static func screen(for caret: CGRect, in screens: [CGRect], within slack: CGFloat = 40) -> CGRect? {
        let p = CGPoint(x: caret.minX, y: caret.midY)
        func outside(_ r: CGRect) -> CGFloat { hypot(max(r.minX - p.x, 0, p.x - r.maxX), max(r.minY - p.y, 0, p.y - r.maxY)) }
        guard let best = screens.min(by: { outside($0) < outside($1) }), outside(best) <= slack else { return nil }
        return best
    }

    /// The window's frame, in AppKit coordinates, and whether the panel sits above the caret. Below the line unless
    /// there isn't room for the panel at its tallest, then above; kept on the caret's display either way.
    static func place(_ caret: CGRect, visible v: CGRect, size: CGSize = Dictation.panelSize) -> (frame: CGRect, above: Bool) {
        func clamp(_ x: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { max(lo, min(x, max(lo, hi))) }
        let roomBelow = caret.minY - gap - v.minY, roomAbove = v.maxY - (caret.maxY + gap)
        let above = roomBelow < room && roomAbove > roomBelow
        // The seed's centre on the caret; the panel then grows right from there, unless the display's edge is near.
        let x = clamp(caret.minX - margin - seed / 2, v.minX - margin, v.maxX - margin - reach)
        let y: CGFloat
        if above {
            // The glass's bottom just over the line, growing up; never so high that its tallest goes off the top.
            y = clamp(caret.maxY + gap, v.minY, v.maxY - room) - margin
        } else {
            // The glass's top just under the line, growing down; never so low that its tallest goes off the bottom.
            y = clamp(caret.minY - gap, v.minY + room, v.maxY) + margin - size.height
        }
        return (CGRect(origin: CGPoint(x: x, y: y), size: size), above)
    }

    /// Where the glass is in the window's frame, in AppKit coordinates: its tallest, left-aligned to the seed.
    static func glass(in frame: CGRect, above: Bool, size: CGSize = Dictation.panelSize) -> CGRect {
        let x = frame.minX + margin
        return above ? CGRect(x: x, y: frame.minY + margin, width: reach, height: room)
                     : CGRect(x: x, y: frame.maxY - margin - room, width: reach, height: room)
    }

    static func selfTest() {
        let main = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let side = CGRect(x: 1440, y: 200, width: 1920, height: 1080)
        let low = CGRect(x: 0, y: -1080, width: 1920, height: 1055) // a display below, its own menu bar off the top
        let screens = [main, side, low]

        // Accessibility to AppKit and back: a 20 pt caret 100 pt down the main display.
        let flipped = flip(CGRect(x: 300, y: 100, width: 0, height: 20), mainHeight: 900)
        precondition(flipped == CGRect(x: 300, y: 780, width: 0, height: 20))
        precondition(flip(flipped, mainHeight: 900) == CGRect(x: 300, y: 100, width: 0, height: 20), "flipping twice is a no-op")

        // Junk answers are refused.
        precondition(plausible(.zero) == nil && plausible(CGRect(x: 4, y: 4, width: 0, height: 0)) == nil)
        precondition(plausible(CGRect(x: 10, y: 10, width: 800, height: 600)) == nil, "an editor's whole view isn't a caret")
        precondition(plausible(CGRect(x: 10, y: 10, width: 0, height: 18)) != nil, "a zero-width caret is fine")

        // The display the caret is on, or none if it's off every one.
        precondition(screen(for: CGRect(x: 2000, y: 600, width: 0, height: 18), in: screens) == side)
        precondition(screen(for: CGRect(x: 500, y: -500, width: 0, height: 18), in: screens) == low)
        precondition(screen(for: CGRect(x: 9000, y: 9000, width: 0, height: 18), in: screens) == nil)

        // In the middle of a display: below the line, the seed centred on the caret.
        let mid = CGRect(x: 400, y: 500, width: 0, height: 18)
        let below = place(mid, visible: main)
        precondition(!below.above)
        precondition(below.frame.minX + margin + seed / 2 == mid.minX, "the seed sits on the caret")
        precondition(below.frame.maxY - margin == mid.minY - gap, "the glass's top is just under the line")

        // Near the bottom: above, the glass's bottom just over the line.
        let bottom = CGRect(x: 400, y: 60, width: 0, height: 18)
        let up = place(bottom, visible: main)
        precondition(up.above && up.frame.minY + margin == bottom.maxY + gap)

        // Near the right edge: pulled left so the orb stays on screen.
        let right = place(CGRect(x: 1430, y: 500, width: 0, height: 18), visible: main)
        precondition(main.contains(glass(in: right.frame, above: right.above)))

        // Everywhere on every display, the panel at its tallest stays on that display and never covers the line.
        for v in screens {
            for fx in stride(from: CGFloat(0), through: 1, by: 0.125) {
                for fy in stride(from: CGFloat(0), through: 1, by: 0.0625) {
                    let c = CGRect(x: v.minX + fx * v.width, y: v.minY + fy * (v.height - 18), width: 0, height: 18)
                    let p = place(c, visible: v)
                    let g = glass(in: p.frame, above: p.above)
                    precondition(v.insetBy(dx: -0.001, dy: -0.001).contains(g), "the panel stays on the caret's display")
                    precondition(p.above ? g.minY >= c.maxY : g.maxY <= c.minY, "the panel never covers the caret's line")
                }
            }
        }
        print("caret self-test passed (placement across displays)")
    }
}
