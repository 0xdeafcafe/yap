import SwiftUI

/// One persistent glass surface owns the smoke and edge lighting as well as the geometry.
/// Foreground labels may cross-fade; the glass body itself continuously reshapes.
struct Pill: View {
    let m: Dictation
    @State private var dripped = false
    /// What the words measure, laid out at the widest they may go: the glass is drawn around it.
    @State private var textSize = CGSize(width: 0, height: 34)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The system's appearance. At the blob the glass is always dark; at the caret it follows the system, like
    /// the rest of the page it sits on.
    @Environment(\.colorScheme) private var scheme

    private var expanded: Bool { m.open }
    private var talking: Bool { expanded && (m.phase == .listening || m.phase == .finishing) }
    private var atCaret: Bool { m.anchor != .blob }
    private var outline: LiquidOutline {
        if atCaret {
            // A bubble that grows out of a dot under the caret: right as the words come, then a line at a time.
            let b = m.bubble
            return LiquidOutline(edge: m.edge, anchor: m.anchor,
                                 width: expanded ? b.width(fitting: textSize) : b.single,
                                 height: expanded ? b.height(fitting: textSize) : b.single,
                                 corner: b.single / 2, orb: 0, orbGap: 0, chip: 0, chipGap: 0)
        }
        // At the edge it grows out of the blob.
        let textHeight = textSize.height
        return LiquidOutline(edge: m.edge, anchor: m.anchor,
                      width: expanded ? 496 : m.hovering ? 184 : m.edge == .bottom ? 44 : 12,
                      height: expanded ? max(34, textHeight) + 44 : m.hovering ? 40 : m.edge == .bottom ? 12 : 44,
                      corner: expanded ? 26 : m.hovering ? 20 : 6,
                      orb: talking ? 1 : 0,
                      // Never past 16, where the neck pinches off: the orb stays joined to the panel however loud you are.
                      orbGap: reduceMotion ? 4 : 1 + 10 * min(max(m.level, 0), 1),
                      chip: m.phase == .done ? 1 : 0,
                      chipGap: reduceMotion || dripped ? 24 : 0,
                      // Expanding carries the blob from where it sits to the middle of the panel.
                      slide: expanded ? 0 : m.slide,
                      pull: expanded ? .zero : m.pull,
                      stretch: expanded ? 1 : m.stretch)
    }

    var body: some View {
        PillSurface(m: m, outline: outline, textSize: $textSize,
                    movingLight: !reduceMotion && (expanded || m.hovering))
        .onPreferenceChange(PointerRegions.self) { m.setHitRegions($0) }
        .environment(\.colorScheme, atCaret ? scheme : .dark)
        // A styling preference, not a promise of key-window compositor highlights.
        .environment(\.appearsActive, true)
        .animation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.86), value: m.phase)
        .animation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.86), value: m.open)
        .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.86), value: m.hovering)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7), value: m.edge)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: m.level)
        .animation(reduceMotion ? nil : atCaret ? .spring(response: 0.3, dampingFraction: 0.9) : .easeInOut(duration: 0.2), value: textSize)
        .task(id: m.phase) {
            dripped = false
            guard m.phase == .done, !reduceMotion else { return }
            // Give the chip an attached frame before it stretches away. Cancel stale drips.
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            withAnimation(.spring(response: 0.65, dampingFraction: 0.86)) { dripped = true }
        }
    }

}

/// Layout and material consume the SAME interpolated geometry. Independent implicit frame/mask
/// animations otherwise drift apart while the panel lifts to make room for the chip.
private struct PointerRegions: PreferenceKey {
    static var defaultValue: [CGRect] { [] }
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

private struct PillSurface: View, Animatable {
    let m: Dictation
    var outline: LiquidOutline
    @Binding var textSize: CGSize
    var movingLight: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    private var expanded: Bool { m.open }
    private var atCaret: Bool { m.anchor != .blob }

    var animatableData: LiquidOutline.AnimatableData {
        get { outline.animatableData }
        set { outline.animatableData = newValue }
    }

    var body: some View {
        let shape = outline
        let frame = shape.mainFrame(in: Dictation.panelSize)
        let mic = shape.orbFrame(in: Dictation.panelSize)
        let pasted = shape.chipFrame(in: Dictation.panelSize)
        let ink: Color = atCaret && scheme == .light ? .black : .white
        ZStack(alignment: .topLeading) {
            GlassSurface(outline: shape, movingLight: movingLight, caret: atCaret)
                .overlay {
                    let press = ink.opacity(m.mousePressed ? 0.22 : m.controlHovered ? (atCaret ? 0.08 : 0.13) : 0)
                    let edge = ink.opacity(m.controlHovered ? (atCaret ? 0.4 : 0.65) : 0)
                    if atCaret {
                        shape.fill(press)
                        shape.stroke(edge, lineWidth: 1)
                    } else {
                        // The pieces, not the hand-made necks between them: the glass draws its own.
                        shape.mainBody.fill(press)
                        Bud(outline: shape, chip: false).fill(press)
                        shape.mainBody.stroke(edge, lineWidth: 1.3)
                            .mask(Unjoined(holes: shape.junctions(in: Dictation.panelSize, melt: GlassSurface.melt)))
                    }
                }
            if atCaret {
                caretContent(frame: frame, ink: ink)
                    .frame(width: Dictation.panelSize.width, height: Dictation.panelSize.height)
                    .mask(shape)
            } else {
            ZStack(alignment: .topLeading) {
                Group {
                    if expanded {
                        panelText
                    } else if m.hovering {
                        (m.armed ? Text("Drag to move") : Text("Click or hold to talk"))
                            .font(.system(size: 15)).foregroundStyle(.white)
                            .fixedSize() // the glass grows around it; wrapping while it's narrow looks broken
                    }
                }
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .frame(width: Dictation.panelSize.width, height: Dictation.panelSize.height, alignment: .topLeading)
                .mask(shape.mainBody)
                .transition(.opacity)

                Pulse(level: m.level, still: reduceMotion)
                    .frame(width: 38, height: 38)
                    .background {
                        Circle().fill(.white.opacity(m.mousePressed ? 0.25 : m.controlHovered ? 0.18 : 0))
                    }
                    .opacity(min(1, max(0, shape.orb)))
                    .position(x: mic.midX, y: mic.midY)

                Label("Pasted", systemImage: "checkmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .opacity(min(1, max(0, shape.chip)))
                    .position(x: pasted.midX, y: pasted.midY)
            }
            .frame(width: Dictation.panelSize.width, height: Dictation.panelSize.height)
            .mask(shape)
            }
        }
        .frame(width: Dictation.panelSize.width, height: Dictation.panelSize.height)
        // At the caret the whole bubble is the button (hands free, click it to paste); the seed there is only ever
        // passing through, so it's never something to click.
        .preference(key: PointerRegions.self, value: expanded
                    ? (m.phase == .listening ? (atCaret ? [frame] : [frame, mic]) : [])
                    : atCaret ? [] : [frame.insetBy(dx: -4, dy: -4)])
        .transaction { $0.animation = nil }
    }

    /// At the caret: the recording light in the leading cap, on the line nearest the caret, then the words. Past
    /// three lines the oldest go off the top, fading as they go. No app name (it's the one you're looking at)
    /// and no Pasted chip: the words landing on the page say that.
    private func caretContent(frame: CGRect, ink: Color) -> some View {
        let b = m.bubble
        let above = m.anchor == .caret(above: true)
        let shown = b.shown(textSize.height)
        let overflows = textSize.height > shown + 0.5
        let listening = m.phase == .listening || m.phase == .finishing
        return ZStack(alignment: .topLeading) {
            caretText(ink: ink)
                .frame(height: shown, alignment: .bottom)
                .clipped()
                .mask {
                    LinearGradient(stops: [.init(color: .black.opacity(overflows ? 0 : 1), location: 0),
                                           .init(color: .black, location: overflows ? min(0.35, b.line / shown) : 0)],
                                   startPoint: .top, endPoint: .bottom)
                }
                // Flying, the words are drawn by the overlay instead, from this very spot: gone from here at once.
                .opacity(expanded && !m.flying ? 1 : 0)
                .transaction(value: m.flying) { $0.animation = nil }
                .position(x: frame.minX + b.textX + b.textWidest / 2,
                          y: above ? frame.maxY - Caret.Bubble.pad - shown / 2 : frame.minY + Caret.Bubble.pad + shown / 2)
            Pulse(level: m.level, still: reduceMotion, scale: 0.62, tint: Color(nsColor: .systemRed))
                .frame(width: b.single, height: b.single)
                .opacity(listening ? 1 : 0)
                .position(x: frame.minX + b.single / 2, y: above ? frame.maxY - b.single / 2 : frame.minY + b.single / 2)
        }
    }

    private func caretText(ink: Color) -> some View {
        let b = m.bubble
        // Peach is too faint on light glass; a deeper orange there.
        let mark = ink == .black ? Color(red: 0.78, green: 0.38, blue: 0.02) : Said.fixColor
        return Group {
            if m.phase == .failed {
                Text(m.error).foregroundStyle(ink.opacity(0.6))
            } else {
                Said(parts: Said.latest(m.shown ?? [(m.settled, .tidied)], keeping: 240 - m.guessing.count), guessing: m.guessing,
                     level: m.level, trailing: trailing, fixed: m.fixed.map(\.now), ink: ink, mark: mark)
            }
        }
        .font(.system(size: b.font))
        .fixedSize(horizontal: false, vertical: true)
        // Measured before the frame, so it's the words' own width: the bubble hugs them until they wrap.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { textSize = $0 }
        .frame(width: b.textWidest, alignment: .leading)
        // Streaming words replace immediately; only the bubble around them changes size.
        .transaction { $0.animation = nil }
    }

    /// Long dictations shrink the text so more of it shows at the same height; past 15 pt the
    /// oldest words go off the top. Counts are roughly what fills the lines at each size.
    private var fit: (size: CGFloat, lines: Int) {
        let count = (m.shown?.reduce(0) { $0 + $1.text.count } ?? m.settled.count) + m.guessing.count
        return count < 140 ? (22, 4) : count < 225 ? (18, 5) : (15, 6)
    }

    /// Hands free always says how to finish, as it isn't obvious; holding fn says it only until you've pasted a few times.
    private var trailing: String? {
        guard m.phase == .listening else { return nil }
        if m.locked { return "click\u{a0}or\u{a0}fn\u{a0}to\u{a0}paste" }
        return Dictation.pastes < 10 ? "let\u{a0}go\u{a0}to\u{a0}paste" : nil
    }

    /// Where it'll paste, so you know before you let go.
    private var target: some View {
        let app = AppInfo.of(m.frontApp)
        return HStack(spacing: 6) {
            if let icon = app.icon { Image(nsImage: icon).resizable().interpolation(.high).frame(width: 14, height: 14) }
            Text(app.name)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white.opacity(0.45))
        .accessibilityLabel("Pasting into \(app.name)")
    }

    private var panelText: some View {
        Group {
            if m.phase == .failed {
                Text(m.error).foregroundStyle(.white.opacity(0.6))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Said(parts: Said.latest(m.shown ?? [(m.settled, .tidied)], keeping: 330 - m.guessing.count), guessing: m.guessing, level: m.level,
                         trailing: trailing, fixed: m.fixed.map(\.now))
                    if m.phase == .listening, !m.frontApp.isEmpty { target }
                }
            }
        }
        .font(.system(size: fit.size))
        .lineLimit(fit.lines).truncationMode(.head)
        .frame(width: 440, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textSize.height = $0 }
        .padding(.horizontal, 28).padding(.vertical, 22)
        // Streaming words replace immediately; only the surrounding body changes size.
        .transaction { $0.animation = nil }
    }
}

/// At the blob, the panel, the orb and the Pasted chip are separate pieces of system Liquid Glass in one
/// GlassEffectContainer, so they melt into each other the way the system's own glass does: a soft neck that thickens
/// as the orb swells in, and stretches and pinches off as the chip drips away, with real refraction and the glass's
/// own specular edge on each. The panel keeps its smoke for the words; the orb and chip are lighter, clearer glass.
/// SwiftUI has no public API to stroke the container's merged contour, so the panel's edge and its moving light are
/// drawn on the panel alone and fade out where a piece melts into it.
/// At the caret it's one shape. With Reduce transparency, one solid union.
private struct GlassSurface: View {
    var outline: LiquidOutline
    var movingLight: Bool
    /// The bubble at the caret: lighter glass in the system's own appearance, so it sits on the page rather than
    /// as a dark slab over it. At the blob it's the dark smoked glass.
    var caret = false
    @Environment(\.colorScheme) private var scheme
    // The look follows System Settings: Liquid Glass Clear or Tinted is applied by the system glass itself;
    // Reduce transparency makes the panel solid; Increase contrast darkens the smoke and brightens the edge.
    @Environment(\.accessibilityReduceTransparency) private var solid
    @Environment(\.colorSchemeContrast) private var contrast

    /// How near the orb and chip must be to start melting into the panel. The glass's neck thins fast with distance
    /// and is gone at about two thirds of this: the orb, at most 11 pt off at its loudest, is always joined; the chip
    /// drips 24 pt away, stretching its neck until it pinches off.
    static let melt: CGFloat = 30

    private var liquid: Bool { !caret && !solid }

    var body: some View {
        let main = outline.mainFrame(in: Dictation.panelSize)
        let strong = contrast == .increased
        let dark = scheme == .dark
        Group {
            if caret {
                if solid {
                    outline.fill(Color(white: dark ? 0.16 : 0.97))
                } else {
                    outline.fill(dark ? Color.black.opacity(strong ? 0.5 : 0.16) : Color.white.opacity(strong ? 0.7 : 0.3))
                        .glassEffect(.regular.tint(dark ? .black.opacity(strong ? 0.4 : 0.1) : .white.opacity(strong ? 0.5 : 0.2)), in: outline)
                }
            } else if solid {
                outline.fill(Color(white: 0.11))
            } else {
                let smoke = LinearGradient(colors: [.black.opacity(strong ? 0.75 : 0.5), .black.opacity(strong ? 0.45 : 0.2)],
                                           startPoint: .init(x: 0.5, y: main.minY / Dictation.panelSize.height),
                                           endPoint: .init(x: 0.5, y: main.maxY / Dictation.panelSize.height))
                // One glass for all three, or the container won't melt them together: the panel's smoke is drawn on it.
                let glass = Glass.regular.tint(.black.opacity(strong ? 0.4 : 0.14))
                GlassEffectContainer(spacing: Self.melt) {
                    ZStack {
                        outline.mainBody.fill(smoke).glassEffect(glass, in: outline.mainBody)
                        Color.clear.glassEffect(glass, in: Bud(outline: outline, chip: false))
                        Color.clear.glassEffect(glass, in: Bud(outline: outline, chip: true))
                    }
                }
            }
        }
            .overlay {
                if caret {
                    outline.stroke((dark ? Color.white : .black).opacity(strong ? 0.6 : dark ? 0.2 : 0.12), lineWidth: strong ? 1.2 : 0.6)
                } else {
                    rim(.white.opacity(strong ? 0.7 : 0.24), lineWidth: strong ? 1.5 : 0.8)
                }
            }
            .overlay {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !movingLight)) { timeline in
                    let angle = movingLight ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) * 60 : 225
                    rim(AngularGradient(
                        stops: [.init(color: .clear, location: 0), .init(color: .clear, location: 0.40),
                                .init(color: .white.opacity(0.9), location: 0.48),
                                .init(color: .white.opacity(0.45), location: 0.51),
                                .init(color: .clear, location: 0.59), .init(color: .clear, location: 1)],
                        center: .init(x: main.midX / Dictation.panelSize.width, y: main.midY / Dictation.panelSize.height),
                        angle: .degrees(angle)), lineWidth: caret ? 1 : 1.2)
                }
                .opacity(caret ? 0.55 : 1)
            }
    }

    /// The edge: of the whole shape, or with liquid glass, of the panel, fading out where the orb or chip melts in.
    @ViewBuilder private func rim<S: ShapeStyle>(_ style: S, lineWidth: CGFloat) -> some View {
        if liquid {
            outline.mainBody.stroke(style, lineWidth: lineWidth)
                .mask(Unjoined(holes: outline.junctions(in: Dictation.panelSize, melt: Self.melt)))
        } else {
            outline.stroke(style, lineWidth: lineWidth)
        }
    }
}

/// The orb or the Pasted chip on its own, for the glass to melt into the panel.
private struct Bud: Shape {
    var outline: LiquidOutline
    var chip: Bool
    func path(in rect: CGRect) -> Path {
        if chip {
            guard outline.chip > 0.001 else { return Path() }
            let f = outline.chipFrame(in: rect.size)
            return Path(roundedRect: f, cornerRadius: f.height / 2)
        }
        guard outline.orb > 0.001 else { return Path() }
        return Path(ellipseIn: outline.orbFrame(in: rect.size))
    }
}

/// Everything but soft holes where pieces melt into the panel: a mask for the panel's own edge.
private struct Unjoined: View {
    var holes: [(at: CGPoint, radius: CGFloat)]
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            ctx.blendMode = .destinationOut
            for h in holes where h.radius > 0.5 {
                let r = h.radius
                ctx.fill(Path(ellipseIn: CGRect(x: h.at.x - r, y: h.at.y - r, width: 2 * r, height: 2 * r)),
                         with: .radialGradient(Gradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.55),
                                                                .init(color: .clear, location: 1)]),
                                               center: h.at, startRadius: 0, endRadius: r))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Public Path unions remove the internal edges before either the glass or border is drawn.
/// The narrow bridges pinch off at 16 pt; separate components then have independent contours.
private struct LiquidOutline: Shape {
    var edge: Dictation.Edge
    /// At the blob, laid out against `edge`; at the caret, against the window's top (below the line) or bottom (above it).
    var anchor = Dictation.Anchor.blob
    var width: CGFloat
    var height: CGFloat
    var corner: CGFloat
    var orb: CGFloat
    var orbGap: CGFloat
    var chip: CGFloat
    var chipGap: CGFloat
    /// Along the edge, from the panel's middle; up or right is positive.
    var slide: CGFloat = 0
    /// Where a drag pulls the blob, in screen points (y up).
    var pull = CGSize.zero
    /// Longer along the pull, thinner across it.
    var stretch: CGFloat = 1
    var drawsAccessories = true

    var mainBody: Self {
        var shape = self
        shape.drawsAccessories = false
        return shape
    }

    typealias Pair = AnimatablePair<CGFloat, CGFloat>
    typealias AnimatableData = AnimatablePair<AnimatablePair<AnimatablePair<Pair, Pair>, AnimatablePair<Pair, Pair>>, AnimatablePair<Pair, CGFloat>>
    var animatableData: AnimatableData {
        get { .init(.init(.init(.init(width, height), .init(corner, orb)), .init(.init(orbGap, chip), .init(chipGap, slide))),
                    .init(.init(pull.width, pull.height), stretch)) }
        set {
            pull = CGSize(width: newValue.second.first.first, height: newValue.second.first.second)
            stretch = newValue.second.second
            let newValue = newValue.first
            width = newValue.first.first.first; height = newValue.first.first.second
            corner = newValue.first.second.first; orb = newValue.first.second.second
            orbGap = newValue.second.first.first; chip = newValue.second.first.second
            chipGap = newValue.second.second.first; slide = newValue.second.second.second
        }
    }

    /// At the caret the orb hangs off the right, as it does from a blob on the left edge.
    private var side: Dictation.Edge { anchor == .blob ? edge : .left }

    func mainFrame(in size: CGSize) -> CGRect {
        let w = max(1, width), h = max(1, height)
        if case .caret(let above) = anchor {
            // Left-aligned to the seed, and pinned to the line, so it grows away from the words you're writing.
            let m = Caret.margin
            return CGRect(x: m, y: above ? size.height - m - h : m, width: w, height: h)
        }
        let x = edge == .right ? size.width - 10 - w : edge == .left ? 10 : (size.width - w) / 2
        let y = edge == .bottom ? size.height - 10 - h - 54 * max(0, chip) : (size.height - h) / 2
        let dx = (edge == .bottom ? slide : 0), dy = (edge == .bottom ? 0 : -slide)
        // Kept inside the panel, so the hint isn't cut off near a corner.
        return CGRect(x: min(max(x + dx, 10), size.width - 10 - w), y: min(max(y + dy, 10), size.height - 10 - h),
                      width: w, height: h)
    }

    func orbFrame(in size: CGSize) -> CGRect {
        let main = mainFrame(in: size), d = 38 * max(0, orb), gap = max(0, orbGap)
        if side == .bottom {
            return CGRect(x: main.midX - d / 2, y: main.minY - gap - d, width: d, height: d)
        }
        return CGRect(x: side == .right ? main.minX - gap - d : main.maxX + gap,
                      y: main.midY - d / 2, width: d, height: d)
    }

    func chipFrame(in size: CGSize) -> CGRect {
        let main = mainFrame(in: size), amount = max(0, chip)
        // Above the caret it drips upwards, away from the line it just pasted into.
        let y = chipsUp ? main.minY - max(0, chipGap) - 30 * amount : main.maxY + max(0, chipGap)
        return CGRect(x: main.midX - 49 * amount, y: y, width: 98 * amount, height: 30 * amount)
    }

    private var chipsUp: Bool { anchor == .caret(above: true) }

    /// Where the orb and the chip meet the panel, and how much of the panel's edge their melt covers: none once
    /// they're `melt` away, and only as much as they've grown in.
    func junctions(in size: CGSize, melt: CGFloat) -> [(at: CGPoint, radius: CGFloat)] {
        let main = mainFrame(in: size)
        // How joined a piece this far off is: fully touching, to nothing where the neck pinches off.
        func joined(_ gap: CGFloat) -> CGFloat { max(0, 1 - max(0, gap) / (melt * 0.65)) }
        var out: [(at: CGPoint, radius: CGFloat)] = []
        if orb > 0.001 {
            let at = side == .bottom ? CGPoint(x: main.midX, y: main.minY)
                : CGPoint(x: side == .right ? main.minX : main.maxX, y: main.midY)
            out.append((at, (orbFrame(in: size).width / 2 + 10) * joined(orbGap)))
        }
        if chip > 0.001 {
            let pasted = chipFrame(in: size)
            out.append((CGPoint(x: pasted.midX, y: chipsUp ? main.minY : main.maxY),
                        (pasted.width / 2 + 8) * joined(chipGap)))
        }
        return out
    }

    func path(in rect: CGRect) -> Path {
        let main = mainFrame(in: rect.size)
        var result = Path(roundedRect: main, cornerRadius: max(0, min(corner, min(main.width, main.height) / 2)))
        if abs(stretch - 1) > 0.001 {
            // Turn the pull onto the x-axis, stretch, turn back. Still one shape, so the glass and edge follow it.
            let c = CGPoint(x: main.midX, y: main.midY), a = atan2(-pull.height, pull.width)
            result = result.applying(CGAffineTransform(translationX: c.x, y: c.y).rotated(by: a)
                .scaledBy(x: stretch, y: 1 / sqrt(stretch)).rotated(by: -a).translatedBy(x: -c.x, y: -c.y))
        }
        guard drawsAccessories else { return result }
        if orb > 0.001 {
            let mic = orbFrame(in: rect.size)
            result = result.union(Path(ellipseIn: mic))
            if orbGap < 16 {
                // Attach only to the straight edge, never into a rounded corner.
                let flatHalf = (side == .bottom ? main.width : main.height) / 2 - corner
                let bridge = circleBridge(radius: mic.width / 2, gap: max(0, orbGap), flatHalf: flatHalf)
                let transform: CGAffineTransform
                switch side {
                case .bottom: transform = .init(a: 0, b: -1, c: 1, d: 0, tx: main.midX, ty: main.minY)
                case .right: transform = .init(a: -1, b: 0, c: 0, d: 1, tx: main.minX, ty: main.midY)
                case .left: transform = .init(translationX: main.maxX, y: main.midY)
                }
                result = result.union(bridge.applying(transform))
            }
        }
        if chip > 0.001 {
            let pasted = chipFrame(in: rect.size)
            result = result.union(Path(roundedRect: pasted, cornerRadius: pasted.height / 2))
            if chipGap < 16 {
                let amount = sqrt(max(0, 1 - chipGap / 16))
                let a = (pasted.width / 2 + 10) * amount
                let b = (pasted.width - pasted.height) / 2 * amount
                // From the panel's edge to the chip's, whichever way it drips.
                let x = pasted.midX, top = chipsUp ? main.minY + 0.5 : main.maxY - 0.5, bottom = chipsUp ? pasted.maxY - 0.5 : pasted.minY + 0.5
                var bridge = Path()
                bridge.move(to: .init(x: x + a, y: top))
                bridge.addCurve(to: .init(x: x + b, y: bottom), control1: .init(x: x + a * 0.15, y: top), control2: .init(x: x + b * 0.15, y: bottom))
                bridge.addLine(to: .init(x: x - b, y: bottom))
                bridge.addCurve(to: .init(x: x - a, y: top), control1: .init(x: x - b * 0.15, y: bottom), control2: .init(x: x - a * 0.15, y: top))
                bridge.closeSubpath()
                result = result.union(bridge)
            }
        }
        return result
    }

    // A flat main-body edge at x=0 connects tangentially to the facing arc of a circular bud.
    private func circleBridge(radius r: CGFloat, gap: CGFloat, flatHalf: CGFloat) -> Path {
        let amount = sqrt(max(0, 1 - gap / 16))
        let theta = .pi * 0.42 * amount
        let a = min((r + 9 * max(0, orb)) * amount, max(0.5, flatHalf - 0.5))
        let x = gap + r - r * cos(theta), y = r * sin(theta)
        let handle = min(x * 0.65, y * 0.45 / max(0.1, cos(theta)))
        var p = Path()
        p.move(to: .init(x: -0.5, y: -a))
        p.addCurve(to: .init(x: x, y: -y), control1: .init(x: -0.5, y: -a * 0.3),
                   control2: .init(x: x - handle * sin(theta), y: -y + handle * cos(theta)))
        p.addLine(to: .init(x: gap + r, y: 0))
        p.addLine(to: .init(x: x, y: y))
        p.addCurve(to: .init(x: -0.5, y: a), control1: .init(x: x - handle * sin(theta), y: y - handle * cos(theta)),
                   control2: .init(x: -0.5, y: a * 0.3))
        p.closeSubpath()
        return p
    }
}

/// Settled words in white, guessed words dim with a band of light sweeping through every 1.6 s,
/// then the caret, then a grey hint like Siri's "— Ask Siri".
struct Said: View {
    /// The settled words, each stretch with its look: all white unless Apple Intelligence is tidying as you talk.
    let parts: [(text: String, look: LivePolish.Look)]
    let guessing: String
    let level: Double
    let trailing: String?
    /// Words Yap put right from what's on screen: underlined, so you see it caught them.
    var fixed: [String] = []
    /// The words' colour: white on the dark glass, black on light glass at the caret.
    var ink: Color = .white
    var mark: Color = Said.fixColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The peach of yap's highlight, the colour a fix is marked in everywhere.
    static let fixColor = Color(red: 1, green: 0.85, blue: 0.66)

    /// `s` as Text, with every whole-word `fixed` in it underlined, in `style` otherwise.
    static func marked<S: ShapeStyle>(_ s: String, fixed: [String], style: S, mark: Color = Said.fixColor) -> Text {
        let words = fixed.filter { !$0.isEmpty }
        guard !words.isEmpty, let re = Patterns.compiled(
            "(?<![\\p{L}\\p{N}])(" + words.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + ")(?![\\p{L}\\p{N}])")
        else { return Text(s).foregroundStyle(style) }
        let ns = s as NSString
        var out = Text(""), at = 0
        for match in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            let r = match.range
            if r.location > at { out = Text("\(out)\(Text(ns.substring(with: NSRange(location: at, length: r.location - at))).foregroundStyle(style))") }
            out = Text("\(out)\(Text(ns.substring(with: r)).foregroundStyle(mark).underline(true, color: mark.opacity(0.7)))")
            at = r.upperBound
        }
        if at < ns.length { out = Text("\(out)\(Text(ns.substring(from: at)).foregroundStyle(style))") }
        return out
    }

    /// The last `keeping` characters from a word boundary, so a long dictation shows its newest
    /// words. Text's own head truncation keeps the first lines and only cuts the last one.
    static func latest(_ s: String, keeping n: Int) -> String {
        guard s.count > n else { return s }
        let tail = s.suffix(max(n, 0))
        return "…" + (tail.firstIndex(of: " ").map { tail[tail.index(after: $0)...] } ?? tail)
    }

    /// The same, keeping each stretch's look: older stretches go first, then the oldest words of the next.
    static func latest(_ parts: [(text: String, look: LivePolish.Look)], keeping n: Int) -> [(text: String, look: LivePolish.Look)] {
        var out: [(text: String, look: LivePolish.Look)] = [], left = max(n, 0)
        for p in parts.reversed() {
            guard left > 0 else { break }
            if p.text.count <= left { out.insert(p, at: 0); left -= p.text.count }
            else { out.insert((latest(p.text, keeping: left), p.look), at: 0); left = 0 }
        }
        return out
    }

    /// Whether anything shown has the band of light: words still guessed, or a sentence being rewritten. Nothing
    /// guessed or rewritten, the clock stops rather than drawing the same frame 120 times a second.
    static func sweeps(_ parts: [(text: String, look: LivePolish.Look)], guessing: String) -> Bool {
        !guessing.isEmpty || parts.contains { $0.look == .rewriting }
    }

    static func selfTest() {
        precondition(!sweeps([("Done.", .tidied), ("and this", .waiting)], guessing: ""))
        precondition(sweeps([("Done.", .tidied)], guessing: "still"))
        precondition(sweeps([("Being rewritten", .rewriting)], guessing: ""))
        precondition(latest([("one two ", .tidied), ("three", .waiting)], keeping: 10).map(\.text) == ["…two ", "three"])
        precondition(latest("one two three", keeping: 20) == "one two three")
        precondition(latest("one two three", keeping: 9) == "…three")
        precondition(latest("abcdef", keeping: 3) == "…def")
        print("said self-test passed")
    }

    var body: some View {
        // Marked once per change, not every frame: only the sweep moves.
        let still = parts.map { p -> Text? in
            switch p.look {
            case .tidied: Self.marked(p.text, fixed: fixed, style: ink, mark: mark)
            case .rewriting: nil
            case .waiting: Self.marked(p.text, fixed: fixed, style: ink.opacity(0.55), mark: mark)
            }
        }
        TimelineView(.animation(paused: reduceMotion || !Self.sweeps(parts, guessing: guessing))) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let x = reduceMotion ? 2 : -0.4 + 1.8 * (t.truncatingRemainder(dividingBy: 1.6) / 1.6)
            let sweep = LinearGradient(
                stops: [.init(color: ink.opacity(0.45), location: 0), .init(color: ink, location: 0.5),
                        .init(color: ink.opacity(0.45), location: 1)],
                startPoint: .init(x: x - 0.15, y: 0.3), endPoint: .init(x: x + 0.15, y: 0.7))
            let gap = guessing.isEmpty || parts.allSatisfy({ $0.text.isEmpty }) || parts.last?.text.last == " " ? "" : " "
            let said = zip(parts, still).reduce(Text("")) { t, p in
                Text("\(t)\(p.1 ?? Text(p.0.text).foregroundStyle(sweep))")
            }
            let caret = Text(Image(systemName: "poweron"))
                .fontWeight(.semibold)
                .foregroundStyle(ink.opacity(0.6 + 0.4 * level))
            // The non-breaking space keeps the dash with its hint, so the hint wraps as one piece.
            Text("""
                \(said)\
                \(Text(gap + guessing).foregroundStyle(sweep))\
                \(caret)\
                \(Text(trailing.map { " —\u{a0}" + $0 } ?? "").foregroundStyle(ink.opacity(0.4)))
                """)
        }
    }
}

/// In the orb, or the bubble's leading cap at the caret like a recording light: a dot with a soft ring that
/// swells as you talk and settles when you stop. It says the mic hears you without chattering at you. With
/// Reduce motion on, nothing changes size; the ring brightens instead.
struct Pulse: View {
    var level: Double
    var still: Bool
    var scale: CGFloat = 1
    var tint: Color = .white

    var body: some View {
        let l = min(max(level, 0), 1)
        let ring = (still ? 22 : 14 + 14 * l) * scale, dot = (still ? 11 : 10 + 3 * l) * scale
        ZStack {
            Circle()
                .stroke(tint.opacity(still ? 0.15 + 0.6 * l : 0.12 + 0.45 * l), lineWidth: 1.5 * max(scale, 0.8))
                .frame(width: ring, height: ring)
            Circle()
                .fill(tint.opacity(0.9))
                .frame(width: dot, height: dot)
        }
        // Its own, gentler spring: the mic's level arrives in steps.
        .animation(still ? nil : .spring(response: 0.35, dampingFraction: 0.9), value: l)
        .accessibilityElement()
        .accessibilityLabel("Listening")
    }
}
