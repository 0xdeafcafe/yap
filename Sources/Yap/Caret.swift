import AppKit

/// Where the text you're about to dictate will go, so the listening panel can sit by it the way macOS's own
/// dictation bubble does. Read through Accessibility: the focused field's insertion point, else a small field's
/// frame. Terminals and some Electron apps don't say, and then the panel stays at the blob.
enum Caret {
    /// The window's clear margin around the glass, as `LiquidOutline` lays it out.
    static let margin: CGFloat = 10
    /// Taller than this isn't a caret or a one-line field; it's an editor or a terminal's whole buffer.
    static let tallest: CGFloat = 120

    /// Clear space between the caret's line and the bubble: more for bigger text, never touching.
    static func gap(for caret: CGRect) -> CGFloat { min(14, max(6, (caret.height * 0.4).rounded())) }

    /// The bubble at the caret, sized from the line it's under so it reads as part of the page rather than a
    /// panel dropped on it: text a point or so bigger than the field's (13 to 15 pt), one to three lines,
    /// hugging what you've said up to `widest`. A recording light sits in its leading cap, under the caret.
    struct Bubble: Equatable {
        var font: CGFloat
        /// From the caret's height, which is the field's line height.
        init(line h: CGFloat) { font = min(15, max(13, (h / 1.25).rounded() + 1)) }
        init(font: CGFloat) { self.font = font }

        static let widest: CGFloat = 400
        static let lines = 3
        /// Above and below the text.
        static let pad: CGFloat = 7
        /// After the text.
        static let trail: CGFloat = 13
        /// One line of the system font at `font`, as the text system lays it out.
        var line: CGFloat {
            let f = NSFont.systemFont(ofSize: font)
            return ceil(f.ascender - f.descender + f.leading)
        }
        /// One line tall: also the dot it grows out of, and the leading cap the recording light sits in.
        var single: CGFloat { line + 2 * Self.pad }
        /// Three lines tall.
        var tallest: CGFloat { line * CGFloat(Self.lines) + 1 + 2 * Self.pad }
        /// Where the text starts, past the cap.
        var textX: CGFloat { single - 2 }
        /// The widest the words get before they wrap.
        var textWidest: CGFloat { Self.widest - textX - Self.trail }
        /// How much of the words shows: all of them, up to three lines (a point spare for rounding).
        func shown(_ textHeight: CGFloat) -> CGFloat { max(0, min(textHeight, line * CGFloat(Self.lines) + 1)) }
        /// The glass around words measuring `text`: a dot with nothing in it, never wider than `widest`.
        func width(fitting text: CGSize) -> CGFloat { min(Self.widest, max(single, textX + text.width + Self.trail)) }
        func height(fitting text: CGSize) -> CGFloat { max(single, shown(text.height) + 2 * Self.pad) }
    }

    // MARK: Reading it

    /// Where Accessibility says the words will go.
    struct Insertion: Equatable, Sendable {
        /// The caret's line (Accessibility's coordinates, top left of the main display, y down), or a small field's frame.
        var rect: CGRect
        /// Where the words go in the field's text, in UTF-16 units: the insertion point or a selection's start. Nil
        /// when `rect` is the field rather than its caret.
        var index: Int?
    }

    /// Accessibility calls that share one deadline, each giving up when it runs out. Call off the main thread.
    struct Reader {
        let deadline: Date
        init(budget: TimeInterval) { deadline = Date().addingTimeInterval(budget) }
        var expired: Bool { Date() >= deadline }
        func remaining() -> Float { Float(max(0.01, deadline.timeIntervalSinceNow)) }
        func get(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
            AXUIElementSetMessagingTimeout(e, remaining())
            var v: CFTypeRef?
            return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
        }
        static func element(_ v: CFTypeRef?) -> AXUIElement? {
            guard let v, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
            return (v as! AXUIElement)
        }
        static func ax(_ v: CFTypeRef?) -> AXValue? {
            guard let v, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
            return (v as! AXValue)
        }
        static func rect(_ v: CFTypeRef?) -> CGRect? {
            var r = CGRect.zero; return ax(v).map { AXValueGetValue($0, .cgRect, &r) } == true ? r : nil
        }
        static func range(_ v: CFTypeRef?) -> CFRange? {
            var r = CFRange(); return ax(v).map { AXValueGetValue($0, .cfRange, &r) } == true ? r : nil
        }
        static func point(_ v: CFTypeRef?) -> CGPoint? {
            var p = CGPoint.zero; return ax(v).map { AXValueGetValue($0, .cgPoint, &p) } == true ? p : nil
        }
        static func size(_ v: CFTypeRef?) -> CGSize? {
            var s = CGSize.zero; return ax(v).map { AXValueGetValue($0, .cgSize, &s) } == true ? s : nil
        }
        /// The focused app's focused element: the field you're typing in.
        func field() -> AXUIElement? {
            guard AXIsProcessTrusted(), let app = Self.element(get(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute))
            else { return nil }
            return Self.element(get(app, kAXFocusedUIElementAttribute))
        }
        func selection(_ field: AXUIElement) -> CFRange? { Self.range(get(field, kAXSelectedTextRangeAttribute)) }
        /// What the app says `location..<location + length` covers, as it said it: no sanity checks.
        func bounds(_ field: AXUIElement, _ location: Int, _ length: Int) -> CGRect? {
            guard location >= 0, length >= 0, !expired else { return nil }
            var range = CFRange(location: location, length: length)
            guard let arg = AXValueCreate(.cfRange, &range) else { return nil }
            AXUIElementSetMessagingTimeout(field, remaining())
            var out: CFTypeRef?
            guard AXUIElementCopyParameterizedAttributeValue(field, kAXBoundsForRangeParameterizedAttribute as CFString, arg, &out) == .success
            else { return nil }
            return Self.rect(out)
        }
    }

    /// The caret in Accessibility's coordinates (top left of the main display, y down), or nil.
    /// Call off the main thread; each call to the app gives up when `budget` runs out.
    nonisolated static func read(budget: TimeInterval = 0.08) -> Insertion? {
        let ax = Reader(budget: budget)
        guard let field = ax.field() else { return nil }
        func bounds(_ location: Int, _ length: Int) -> CGRect? { ax.bounds(field, location, length).flatMap(plausible) }
        if let range = ax.selection(field) {
            // Where the words go: the start of a selection (it's replaced) or the insertion point. Some apps give
            // the insertion point as a sliver at the top of its line, so the characters either side say how tall
            // the line really is.
            let at = range.location
            let caret = bounds(at, 0)
            let before = at > 0 ? bounds(at - 1, 1) : nil
            let after = before == nil ? bounds(at, 1) : nil
            if let r = line(caret: caret, before: before, after: after) { return Insertion(rect: r, index: at) }
        }
        // No caret, but a field small enough that sitting below it is as good.
        guard let origin = Reader.point(ax.get(field, kAXPositionAttribute)), let size = Reader.size(ax.get(field, kAXSizeAttribute)),
              let r = plausible(CGRect(origin: origin, size: size)) else { return nil }
        return Insertion(rect: r, index: nil)
    }

    /// Apps answer an unknown position with zero, an empty line with no height, and an editor with its whole view.
    nonisolated static func plausible(_ r: CGRect) -> CGRect? {
        guard r.origin.x.isFinite, r.origin.y.isFinite, r.height > 1, r.height <= tallest,
              r.width >= 0, r.width < 4000, r.origin != .zero else { return nil }
        return r
    }

    /// The insertion point as a zero-width rect as tall as its line, from what the app said (Accessibility's
    /// coordinates, y down). A neighbouring character only counts if it's on the caret's line: the one before a
    /// line's start is at the end of the line above.
    nonisolated static func line(caret: CGRect?, before: CGRect?, after: CGRect?) -> CGRect? {
        func sameLine(_ a: CGRect, _ b: CGRect) -> Bool { min(a.maxY, b.maxY) - max(a.minY, b.minY) > 0.5 }
        var r: CGRect
        if let caret {
            r = CGRect(x: caret.minX, y: caret.minY, width: 0, height: caret.height)
            for c in [before, after].compactMap({ $0 }) where sameLine(c, r) {
                let top = min(r.minY, c.minY), bottom = max(r.maxY, c.maxY)
                r = CGRect(x: r.minX, y: top, width: 0, height: bottom - top)
            }
        } else if let before {
            r = CGRect(x: before.maxX, y: before.minY, width: 0, height: before.height)
        } else if let after {
            r = CGRect(x: after.minX, y: after.minY, width: 0, height: after.height)
        } else { return nil }
        // Still a sliver: take it as the top of a line of ordinary text.
        if r.height < 10 { r.size.height = 16 }
        return plausible(r)
    }

    /// Reads the caret on another thread, giving up after `timeout` so a hung app never holds the panel up.
    static func find(timeout: TimeInterval = 0.1) async -> Insertion? { await offMain(timeout: timeout) { read() } }

    /// `work` on another thread, or nil once `timeout` has passed, whichever's first. For Accessibility reads, which
    /// wait on the other app.
    static func offMain<T: Sendable>(timeout: TimeInterval, _ work: @escaping @Sendable () -> T?) async -> T? {
        await withCheckedContinuation { (cont: CheckedContinuation<T?, Never>) in
            let lock = NSLock(); nonisolated(unsafe) var done = false
            @Sendable func finish(_ r: T?) { lock.lock(); defer { lock.unlock() }; if !done { done = true; cont.resume(returning: r) } }
            DispatchQueue.global(qos: .userInteractive).async { finish(work()) }
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

    /// The window's frame, in AppKit coordinates, and whether the bubble sits above the caret. Below the line, a
    /// clear gap under it, unless there isn't room for the bubble at its tallest, then above; kept on the caret's
    /// display either way. The recording light in its leading cap sits under (or over) the caret.
    static func place(_ caret: CGRect, visible v: CGRect, bubble b: Bubble, size: CGSize = Dictation.panelSize) -> (frame: CGRect, above: Bool) {
        func clamp(_ x: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { max(lo, min(x, max(lo, hi))) }
        let gap = gap(for: caret), room = b.tallest
        let roomBelow = caret.minY - gap - v.minY, roomAbove = v.maxY - (caret.maxY + gap)
        let above = roomBelow < room && roomAbove > roomBelow
        let x = clamp(caret.minX - margin - b.single / 2, v.minX - margin, v.maxX - margin - Bubble.widest)
        let y: CGFloat
        if above {
            // The glass's bottom a gap over the line, growing up; never so high that its tallest goes off the top.
            y = clamp(caret.maxY + gap, v.minY, v.maxY - room) - margin
        } else {
            // The glass's top a gap under the line, growing down; never so low that its tallest goes off the bottom.
            y = clamp(caret.minY - gap, v.minY + room, v.maxY) + margin - size.height
        }
        return (CGRect(origin: CGPoint(x: x, y: y), size: size), above)
    }

    /// Where the glass is in the window's frame, in AppKit coordinates, at its widest and tallest.
    static func glass(in frame: CGRect, above: Bool, bubble b: Bubble) -> CGRect {
        let x = frame.minX + margin
        return above ? CGRect(x: x, y: frame.minY + margin, width: Bubble.widest, height: b.tallest)
                     : CGRect(x: x, y: frame.maxY - margin - b.tallest, width: Bubble.widest, height: b.tallest)
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

        // Sized from the field's text: 12 pt TextEdit (a 14 pt line) gets 13 pt, big text never more than 15.
        precondition(Bubble(line: 14).font == 13 && Bubble(line: 18).font == 15 && Bubble(line: 60).font == 15)
        precondition(Bubble(line: 16).font == 14 && Bubble(line: 4).font == 13)
        for f: CGFloat in [13, 14, 15] {
            let b = Bubble(font: f)
            precondition(b.line >= f && b.line <= f * 1.3, "a line is about the font's size")
            precondition(b.tallest <= 72 && b.single <= 34, "it's a compact bubble, not a panel")
            precondition(b.textWidest > 300 && Bubble.widest <= 420)
            // It hugs the words: a dot with none, growing right as they come, then wrapping at the widest.
            precondition(b.width(fitting: .zero) < b.single + Bubble.trail && b.height(fitting: .zero) == b.single)
            precondition(b.width(fitting: CGSize(width: 60, height: b.line)) < 120)
            precondition(b.width(fitting: CGSize(width: b.textWidest, height: b.line)) == Bubble.widest)
            precondition(b.height(fitting: CGSize(width: 0, height: b.line * 9)) == b.tallest, "older lines go off the top")
        }

        // The line under the caret: a sliver at the top of a TextEdit line grows to the character beside it.
        let sliver = CGRect(x: 120, y: 100, width: 0, height: 2), dot = CGRect(x: 114, y: 100, width: 6, height: 15)
        precondition(line(caret: sliver, before: dot, after: nil) == CGRect(x: 120, y: 100, width: 0, height: 15))
        // The character before a line's start is on the line above, and doesn't count.
        let above = CGRect(x: 400, y: 85, width: 5, height: 15)
        precondition(line(caret: CGRect(x: 20, y: 100, width: 0, height: 15), before: above, after: nil)
                     == CGRect(x: 20, y: 100, width: 0, height: 15))
        precondition(line(caret: nil, before: dot, after: nil) == CGRect(x: 120, y: 100, width: 0, height: 15))
        precondition(line(caret: nil, before: nil, after: dot) == CGRect(x: 114, y: 100, width: 0, height: 15))
        precondition(line(caret: CGRect(x: 20, y: 100, width: 0, height: 2), before: nil, after: nil)?.height == 16, "a lone sliver is a line")
        precondition(line(caret: nil, before: nil, after: nil) == nil)

        let b = Bubble(line: 18)
        // In the middle of a display: below the line, a clear gap under it, the recording light under the caret.
        let mid = CGRect(x: 400, y: 500, width: 0, height: 18)
        let below = place(mid, visible: main, bubble: b)
        precondition(!below.above)
        precondition(below.frame.minX + margin + b.single / 2 == mid.minX, "the light sits under the caret")
        precondition(below.frame.maxY - margin == mid.minY - gap(for: mid), "the glass's top is a gap under the line")
        precondition(gap(for: mid) >= 6 && gap(for: CGRect(x: 0, y: 0, width: 0, height: 60)) <= 14)

        // Near the bottom: above, the glass's bottom a gap over the line.
        let bottom = CGRect(x: 400, y: 60, width: 0, height: 18)
        let up = place(bottom, visible: main, bubble: b)
        precondition(up.above && up.frame.minY + margin == bottom.maxY + gap(for: bottom))
        // Just enough room below for three lines: still below.
        let snug = CGRect(x: 400, y: main.minY + b.tallest + gap(for: mid) + 1, width: 0, height: 18)
        precondition(!place(snug, visible: main, bubble: b).above)

        // Near the right edge: pulled left so it stays on screen.
        let right = place(CGRect(x: 1430, y: 500, width: 0, height: 18), visible: main, bubble: b)
        precondition(main.contains(glass(in: right.frame, above: right.above, bubble: b)))

        // Everywhere on every display, at every size, the bubble at its widest and tallest stays on that display and
        // keeps a clear gap from the caret's line.
        for v in screens {
            for h: CGFloat in [10, 14, 18, 30] {
                let b = Bubble(line: h)
                for fx in stride(from: CGFloat(0), through: 1, by: 0.125) {
                    for fy in stride(from: CGFloat(0), through: 1, by: 0.0625) {
                        let c = CGRect(x: v.minX + fx * v.width, y: v.minY + fy * (v.height - h), width: 0, height: h)
                        let p = place(c, visible: v, bubble: b)
                        let g = glass(in: p.frame, above: p.above, bubble: b)
                        precondition(v.insetBy(dx: -0.001, dy: -0.001).contains(g), "the bubble stays on the caret's display")
                        precondition(p.above ? g.minY >= c.maxY + 6 : g.maxY <= c.minY - 6, "the bubble never touches the caret's line")
                    }
                }
            }
        }
        print("caret self-test passed (bubble size, line, placement across displays)")
    }
}
