import AppKit
import SwiftUI

/// The words landing on the page at the caret. Yap can't animate inside another app's field, so it fakes it in its
/// own click-through overlay: the bubble's words fly to the insertion point, shrinking or growing to the field's
/// size as the glass dissolves under them, the paste lands just before they arrive, and they cross-fade out once
/// the app's own text is there. Then a soft band of light sweeps once over what was pasted, the way Writing Tools
/// marks its rewrites. Never at the blob, and none of it with Reduce motion: there the bubble just fades.
enum Landing {
    // MARK: Timing

    enum Timing {
        /// The words' flight, a smooth spring with no overshoot past the caret.
        static let flight: TimeInterval = 0.24
        /// The paste goes a little before the words arrive, so the app's text is drawing as they land. Never later
        /// than the flight: the paste is never held up more than that.
        static let paste: TimeInterval = 0.19
        /// The glass dissolves under the words as they leave.
        static let glass: TimeInterval = 0.16
        /// From the paste to the overlay words starting to go, and how fast they go: quick enough that their
        /// not-quite-the-app's font never registers.
        static let hold: TimeInterval = 0.07
        static let crossFade: TimeInterval = 0.09
        /// The band of light over what was pasted.
        static let sweep: TimeInterval = 0.6
        /// From the paste to first asking where the words went, then between tries while the app catches up.
        static let firstLook: TimeInterval = 0.05
        static let retry: TimeInterval = 0.06
        static let tries = 4
        /// Each Accessibility read gives up after this.
        static let read: TimeInterval = 0.1
    }

    // MARK: The flight

    /// One flight, in AppKit coordinates (y up).
    struct Flight: Equatable {
        /// The words' block where they sit in the bubble: all of it, including lines scrolled off the bubble's top.
        var source: CGRect
        /// The same block at the caret, scaled.
        var target: CGRect
        var scale: CGFloat
        /// How much of the block's bottom the bubble shows; the rest is revealed as the words fly.
        var shown: CGFloat
        /// The overlay's frame: both ends, with room to spare.
        var window: CGRect
    }

    /// The type's scale at the caret: the bubble's line to the field's, which is the caret's height.
    static func scale(caretHeight h: CGFloat, bubble b: Caret.Bubble) -> CGFloat {
        min(2.5, max(0.5, h / b.line))
    }

    /// Past this many lines the words would fly as a wall: the bubble just fades.
    static let mostLines = 8

    /// How tall `text` lays out in the bubble, in whole lines (the bubble's own words are measured the same way).
    static func height(of text: String, bubble b: Caret.Bubble) -> CGFloat {
        let font = NSFont.systemFont(ofSize: b.font)
        let r = NSAttributedString(string: text, attributes: [.font: font])
            .boundingRect(with: CGSize(width: b.textWidest, height: 100_000), options: [.usesLineFragmentOrigin, .usesFontLeading])
        return lines(r.height, bubble: b)
    }

    /// A measured height as a whole number of the bubble's lines, at least one.
    static func lines(_ h: CGFloat, bubble b: Caret.Bubble) -> CGFloat {
        CGFloat(max(1, Int((h / b.line).rounded()))) * b.line
    }

    /// The words' block in the bubble, from the window's frame: as `Pill` lays them out, past the leading cap,
    /// bottom-aligned in what shows. Below the caret the glass hangs from the window's top; above, it stands on its bottom.
    static func source(panel: CGRect, above: Bool, bubble b: Caret.Bubble, height h: CGFloat) -> CGRect {
        let x = panel.minX + Caret.margin + b.textX
        let top = above ? panel.minY + Caret.margin + Caret.Bubble.pad + h
                        : panel.maxY - Caret.margin - Caret.Bubble.pad + (h - b.shown(h))
        return CGRect(x: x, y: top - h, width: b.textWidest, height: h)
    }

    /// The block at the caret: its first line on the caret's line, starting at the insertion point, at the field's size.
    static func target(caret: CGRect, block: CGSize, scale s: CGFloat) -> CGRect {
        CGRect(x: caret.minX, y: caret.maxY - block.height * s, width: block.width * s, height: block.height * s)
    }

    /// The whole flight, or nil when the words shouldn't fly (too many of them).
    static func flight(panel: CGRect, above: Bool, bubble b: Caret.Bubble, height h: CGFloat, caret: CGRect) -> Flight? {
        guard h > 0, h <= b.line * CGFloat(mostLines) + 1, caret.height > 0 else { return nil }
        let s = scale(caretHeight: caret.height, bubble: b)
        let from = source(panel: panel, above: above, bubble: b, height: h)
        let to = target(caret: caret, block: from.size, scale: s)
        return Flight(source: from, target: to, scale: s, shown: b.shown(h), window: from.union(to).insetBy(dx: -12, dy: -12).integral)
    }

    /// A rect in AppKit's screen coordinates, in a window's SwiftUI coordinates (top left, y down).
    static func local(_ r: CGRect, in window: CGRect) -> CGRect {
        CGRect(x: r.minX - window.minX, y: window.maxY - r.maxY, width: r.width, height: r.height)
    }

    // MARK: What was pasted

    /// The words to light up within what's pasted, in UTF-16 units: not the space Yap adds, nor any spaces or line
    /// breaks either end.
    static func lit(_ text: String) -> (offset: Int, length: Int)? {
        let u = Array(text.utf16)
        func blank(_ c: UInt16) -> Bool { c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0 }
        guard let first = u.firstIndex(where: { !blank($0) }), let last = u.lastIndex(where: { !blank($0) }) else { return nil }
        return (first, last - first + 1)
    }

    /// The paste has landed when the caret's just past it.
    static func landed(at index: Int, pasted: Int, caret now: Int?) -> Bool { now == index + pasted }

    /// The lines the pasted words cover, in Accessibility's coordinates, or nil when what the app said is junk. From
    /// the first and last characters (each must look like a character on a line, as `Caret.plausible` judges) and
    /// the whole range's bounds, if the app gave sane ones. One line: first to last. More: the first line from its
    /// first character to the right edge, full lines between, the last up to its last character, the way a
    /// selection's drawn. An app that only gives the first line for the whole range still gets a shape, narrower.
    static func region(whole: CGRect?, first: CGRect?, last: CGRect?, caret: CGRect) -> [CGRect]? {
        guard let first = first.flatMap(Caret.plausible), let last = last.flatMap(Caret.plausible) else { return nil }
        func sameLine(_ a: CGRect, _ b: CGRect) -> Bool { min(a.maxY, b.maxY) - max(a.minY, b.minY) > 0.5 }
        // The words start on the caret's line, or the next when the first one wrapped.
        let h = max(caret.height, first.height)
        guard first.minY >= caret.minY - h / 2, first.minY <= caret.maxY + h / 2 + 2 else { return nil }
        if sameLine(first, caret), abs(first.minX - caret.minX) > max(24, h * 1.5) { return nil }
        if sameLine(first, last) {
            guard last.maxX >= first.minX else { return nil }
            return [CGRect(x: first.minX, y: min(first.minY, last.minY), width: last.maxX - first.minX,
                           height: max(first.maxY, last.maxY) - min(first.minY, last.minY))]
        }
        guard last.minY >= first.maxY - 0.5 else { return nil } // the end before the start
        guard last.maxY - first.minY <= Caret.tallest * 4 else { return nil } // a wall of text: leave it be
        let whole = whole.flatMap { w -> CGRect? in
            guard w.minX.isFinite, w.minY.isFinite, w.width.isFinite, w.height.isFinite, w.origin != .zero,
                  w.width > 0, w.width < 4000, w.height <= Caret.tallest * 4,
                  w.minY <= first.minY + 1, w.maxY >= first.maxY - 1 else { return nil }
            return w
        }
        let left = min(whole?.minX ?? last.minX, last.minX)
        let right = max(whole?.maxX ?? first.maxX, first.maxX, last.maxX)
        guard right > left, right - left < 4000 else { return nil }
        var out = [CGRect(x: first.minX, y: first.minY, width: max(right - first.minX, first.width), height: first.height)]
        if last.minY - first.maxY > 1 {
            out.append(CGRect(x: left, y: first.maxY, width: right - left, height: last.minY - first.maxY))
        }
        out.append(CGRect(x: left, y: last.minY, width: max(last.maxX - left, last.width), height: last.height))
        return out
    }

    /// What the app said about the pasted words, once the paste is in.
    struct Read: Sendable { var whole, first, last: CGRect? }

    /// Asks the focused field where the pasted words went. Nil while the paste hasn't landed (the caret isn't just
    /// past it yet), so the caller can look again. Call off the main thread.
    nonisolated static func read(index: Int, lit: (offset: Int, length: Int), pasted: Int, budget: TimeInterval = 0.08,
                                 in given: AXUIElement? = nil) -> Read? {
        let ax = Caret.Reader(budget: budget)
        guard let field = given ?? ax.field(), landed(at: index, pasted: pasted, caret: ax.selection(field)?.location) else { return nil }
        let at = index + lit.offset
        return Read(whole: ax.bounds(field, at, lit.length), first: ax.bounds(field, at, 1),
                    last: ax.bounds(field, at + lit.length - 1, 1))
    }

    static func selfTest() {
        let b = Caret.Bubble(font: 14)
        // Type scale: the bubble's line to the field's.
        precondition(abs(scale(caretHeight: b.line, bubble: b) - 1) < 0.001, "the same line height flies at the same size")
        precondition(scale(caretHeight: b.line * 2, bubble: b) == 2 && scale(caretHeight: 1000, bubble: b) == 2.5)
        precondition(scale(caretHeight: 2, bubble: b) == 0.5, "never vanishingly small")
        precondition(lines(b.line * 2.1, bubble: b) == b.line * 2 && lines(0, bubble: b) == b.line)
        precondition(height(of: "Hi", bubble: b) == b.line && height(of: String(repeating: "word ", count: 60), bubble: b) > b.line * 2)

        // Where the words sit: past the leading cap, a pad under the glass's top (below the caret) or over its bottom (above).
        let panel = CGRect(origin: CGPoint(x: 100, y: 400), size: Dictation.panelSize)
        let one = source(panel: panel, above: false, bubble: b, height: b.line)
        precondition(one.minX == panel.minX + Caret.margin + b.textX && one.width == b.textWidest)
        precondition(one.maxY == panel.maxY - Caret.margin - Caret.Bubble.pad, "the first line under the glass's top")
        let up = source(panel: panel, above: true, bubble: b, height: b.line * 2)
        precondition(up.minY == panel.minY + Caret.margin + Caret.Bubble.pad && up.height == b.line * 2, "the last line over the glass's bottom")
        // Five lines below: the bubble shows the last three; the first two are above the glass's top, hidden.
        let five = source(panel: panel, above: false, bubble: b, height: b.line * 5)
        precondition(abs(five.minY - (panel.maxY - Caret.margin - Caret.Bubble.pad - b.shown(b.line * 5))) < 0.001)
        precondition(five.maxY > panel.maxY - Caret.margin, "the hidden lines are above the glass")

        // Where they land: the first line on the caret's, from the insertion point, at the field's size.
        let caret = CGRect(x: 300, y: 600, width: 0, height: b.line * 1.5)
        let t = target(caret: caret, block: CGSize(width: 200, height: b.line * 2), scale: 1.5)
        precondition(t.minX == 300 && t.maxY == caret.maxY && t.height == b.line * 3 && t.width == 300)
        let f = flight(panel: panel, above: false, bubble: b, height: b.line * 2, caret: caret)!
        precondition(f.window.contains(f.source) && f.window.contains(f.target) && f.scale == 1.5)
        precondition(f.target.maxY == caret.maxY && f.target.minX == caret.minX, "the first line lands on the caret's line")
        precondition(flight(panel: panel, above: false, bubble: b, height: b.line * 20, caret: caret) == nil, "a wall of words doesn't fly")
        precondition(local(CGRect(x: 110, y: 410, width: 10, height: 10), in: CGRect(x: 100, y: 400, width: 50, height: 50))
                     == CGRect(x: 10, y: 30, width: 10, height: 10))

        // What lights up: the words, not the space after them, in UTF-16 units.
        precondition(lit("Hi there") ?? (0, 0) == (0, 8) && lit("  hi \n") ?? (0, 0) == (2, 2) && lit(" \n ") == nil)
        precondition(lit("café 👋") ?? (0, 0) == (0, 7), "an emoji is two UTF-16 units")
        precondition(landed(at: 10, pasted: 6, caret: 16) && !landed(at: 10, pasted: 6, caret: 10) && !landed(at: 10, pasted: 6, caret: nil))

        // The region, in Accessibility's coordinates (y down). One line: first character to last.
        let at = CGRect(x: 100, y: 200, width: 0, height: 16)
        let h = CGRect(x: 100, y: 200, width: 8, height: 16), e = CGRect(x: 180, y: 200, width: 7, height: 16)
        precondition(region(whole: CGRect(x: 100, y: 200, width: 87, height: 16), first: h, last: e, caret: at)
                     == [CGRect(x: 100, y: 200, width: 87, height: 16)])
        precondition(region(whole: nil, first: h, last: e, caret: at) == [CGRect(x: 100, y: 200, width: 87, height: 16)], "no whole: still fine")
        // Three lines: the first to the right edge, one full line, the last to its end.
        let end = CGRect(x: 40, y: 232, width: 7, height: 16)
        let three = region(whole: CGRect(x: 20, y: 200, width: 480, height: 48), first: h, last: end, caret: at)!
        precondition(three == [CGRect(x: 100, y: 200, width: 400, height: 16), CGRect(x: 20, y: 216, width: 480, height: 16),
                               CGRect(x: 20, y: 232, width: 27, height: 16)])
        // Two lines, an app that only gives the first line's bounds for the whole range: still two lines.
        let next = CGRect(x: 20, y: 216, width: 7, height: 16)
        let two = region(whole: CGRect(x: 100, y: 200, width: 300, height: 16), first: h, last: next, caret: at)!
        precondition(two.count == 2 && two[0].maxX == 400 && two[1].minX == 20 && two[1].maxY == 232)
        // Junk is refused: no first character, a zero rect, the words somewhere else, the end before the start.
        precondition(region(whole: nil, first: nil, last: e, caret: at) == nil)
        precondition(region(whole: nil, first: .zero, last: e, caret: at) == nil)
        precondition(region(whole: nil, first: CGRect(x: 100, y: 700, width: 8, height: 16), last: e, caret: at) == nil, "not by the caret")
        precondition(region(whole: nil, first: CGRect(x: 600, y: 200, width: 8, height: 16), last: CGRect(x: 640, y: 200, width: 8, height: 16),
                            caret: at) == nil, "the caret's line, but far from the caret")
        precondition(region(whole: nil, first: h, last: CGRect(x: 40, y: 150, width: 7, height: 16), caret: at) == nil)
        precondition(region(whole: nil, first: h, last: CGRect(x: 40, y: 900, width: 7, height: 16), caret: at) == nil, "a wall of text")
        precondition(region(whole: nil, first: h, last: CGRect(x: 60, y: 200, width: 7, height: 16), caret: at) == nil, "backwards on one line")
        // The first word wrapped onto the next line: still by the caret.
        precondition(region(whole: nil, first: CGRect(x: 20, y: 216, width: 8, height: 16), last: CGRect(x: 60, y: 216, width: 7, height: 16),
                            caret: CGRect(x: 498, y: 200, width: 0, height: 16)) != nil)
        // A junk whole is ignored rather than trusted.
        let wild = region(whole: CGRect(x: 0, y: 0, width: 9000, height: 9000), first: h, last: next, caret: at)!
        precondition(wild.allSatisfy { $0.width < 1000 })

        // Timing: the paste is never held up longer than the flight, and the words go soon after it.
        precondition(Timing.paste <= Timing.flight && Timing.flight >= 0.2 && Timing.flight <= 0.26)
        precondition(Timing.glass <= Timing.flight && Timing.hold + Timing.crossFade <= 0.2)
        precondition(Timing.sweep >= 0.5 && Timing.sweep <= 0.7)
        print("landing self-test passed (flight, type scale, pasted region)")
    }
}

// MARK: Drawing it

/// A click-through window over everything for the flight and the sweep. One at a time of each.
@MainActor final class Lander {
    private var flightWindow: NSPanel?
    private var sweepWindow: NSPanel?

    private func window(_ frame: CGRect, _ view: some View) -> NSPanel {
        let p = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false
        p.level = .statusBar; p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        p.contentView = host
        p.setFrame(frame, display: false)
        return p
    }

    /// The words leave the bubble for the caret.
    func fly(_ f: Landing.Flight, text: Text, font: CGFloat, ink: Color) {
        flightWindow?.close()
        let w = window(f.window, FlightView(f: f, text: text, font: font, ink: ink))
        flightWindow = w
        w.orderFrontRegardless()
    }

    /// The app's own words are in: the overlay's go, quickly.
    func land() {
        guard let w = flightWindow else { return }
        flightWindow = nil
        NSAnimationContext.runAnimationGroup({ $0.duration = Landing.Timing.crossFade; w.animator().alphaValue = 0 },
                                             completionHandler: { w.close() })
    }

    /// The band of light over `lines`, in AppKit's screen coordinates.
    func sweep(_ lines: [CGRect]) {
        guard let all = lines.first.map({ lines.reduce($0) { $0.union($1) } }) else { return }
        sweepWindow?.close()
        let frame = all.insetBy(dx: -16, dy: -12).integral
        let w = window(frame, SweepView(lines: lines.map { Landing.local($0, in: frame) }))
        sweepWindow = w
        w.orderFrontRegardless()
        Task {
            try? await Task.sleep(for: .seconds(Landing.Timing.sweep + 0.05))
            if sweepWindow === w { sweepWindow = nil }
            w.close()
        }
    }
}

private struct FlightView: View {
    let f: Landing.Flight
    let text: Text
    let font: CGFloat
    let ink: Color
    @State private var t: CGFloat = 0
    var body: some View {
        FlyingWords(f: f, text: text, font: font, ink: ink, t: t)
            .onAppear { withAnimation(.smooth(duration: Landing.Timing.flight)) { t = 1 } }
    }
}

/// The words at `t` of the way from the bubble (0) to the caret (1). The lines the bubble had scrolled off its top
/// unroll as they go, and the type takes the field's size.
private struct FlyingWords: View, Animatable {
    let f: Landing.Flight
    let text: Text
    let font: CGFloat
    let ink: Color
    var t: CGFloat
    var animatableData: CGFloat { get { t } set { t = newValue } }

    var body: some View {
        let from = Landing.local(f.source, in: f.window), to = Landing.local(f.target, in: f.window)
        let s = 1 + (f.scale - 1) * t
        let x = from.minX + (to.minX - from.minX) * t, y = from.minY + (to.minY - from.minY) * t
        let block = f.source.size
        // What's hidden above the bubble's three lines, revealed as the words fly; its edge fades over a line.
        let hidden = max(0, block.height - f.shown) * (1 - t)
        let edge = hidden > 0.5 ? min(block.height - hidden, font * 1.3) : 0
        text
            .font(.system(size: font))
            .foregroundStyle(ink)
            .frame(width: block.width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: block.width, height: block.height, alignment: .topLeading)
            .mask(alignment: .top) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: hidden)
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: edge)
                    Color.black
                }
            }
            .scaleEffect(s, anchor: .topLeading)
            .offset(x: x, y: y)
            .frame(width: f.window.width, height: f.window.height, alignment: .topLeading)
            .allowsHitTesting(false)
    }
}

private struct SweepView: View {
    let lines: [CGRect]
    @State private var p: CGFloat = 0
    var body: some View {
        Sweep(lines: lines, p: p)
            .onAppear { withAnimation(.easeInOut(duration: Landing.Timing.sweep)) { p = 1 } }
    }
}

/// A soft band of Apple Intelligence's colours passing once over the lines, left to right, in and out.
private struct Sweep: View, Animatable {
    let lines: [CGRect]
    var p: CGFloat
    var animatableData: CGFloat { get { p } set { p = newValue } }
    @Environment(\.colorScheme) private var scheme

    static let colors = [Color(red: 0.25, green: 0.55, blue: 1), Color(red: 0.62, green: 0.38, blue: 1),
                         Color(red: 1, green: 0.38, blue: 0.62), Color(red: 1, green: 0.62, blue: 0.28)]

    var body: some View {
        GeometryReader { g in
            let all = lines.dropFirst().reduce(lines.first ?? .zero) { $0.union($1) }
            let band = max(90, all.width * 0.5)
            // The band's middle, from just before the words to just past them.
            let mid = all.minX - band / 2 + (all.width + band) * p
            let w = max(1, g.size.width)
            let start = UnitPoint(x: (mid - band / 2) / w, y: 0.35), end = UnitPoint(x: (mid + band / 2) / w, y: 0.65)
            let light = LinearGradient(stops: [.init(color: .clear, location: 0)]
                                       + Self.colors.enumerated().map { .init(color: $1, location: 0.15 + 0.7 * CGFloat($0) / 3) }
                                       + [.init(color: .clear, location: 1)], startPoint: start, endPoint: end)
            let shape = Lines(rects: lines)
            // In and out: nothing at either end of the sweep.
            let swell = sin(.pi * min(max(p, 0), 1))
            ZStack {
                // A wide soft glow, then a brighter core on the words themselves.
                light.mask(shape.inset(-5).blur(radius: 7)).opacity(0.42)
                light.mask(shape.inset(-1).blur(radius: 2)).opacity(scheme == .dark ? 0.4 : 0.3)
            }
            .opacity(swell)
        }
        .allowsHitTesting(false)
    }
}

/// Rounded rects around each line of the pasted words, as one shape.
private struct Lines: Shape {
    var rects: [CGRect]
    var by: CGFloat = 0
    func inset(_ d: CGFloat) -> Self { var s = self; s.by = d; return s }
    func path(in _: CGRect) -> Path {
        rects.reduce(Path()) { p, r in
            let r = r.insetBy(dx: by, dy: by)
            return p.union(Path(roundedRect: r, cornerRadius: min(5, r.height / 3)))
        }
    }
}

