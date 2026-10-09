import SwiftUI

/// One persistent glass surface owns the smoke and edge lighting as well as the geometry.
/// Foreground labels may cross-fade; the glass body itself continuously reshapes.
struct Pill: View {
    let m: Dictation
    @State private var dripped = false
    @State private var textHeight: CGFloat = 34
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var talking: Bool { m.phase == .listening || m.phase == .finishing }
    private var expanded: Bool { m.phase != .hidden }
    private var outline: LiquidOutline {
        LiquidOutline(edge: m.edge,
                      width: expanded ? 496 : m.hovering ? 168 : m.edge == .bottom ? 44 : 12,
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
        PillSurface(m: m, outline: outline, textHeight: $textHeight,
                    movingLight: !reduceMotion && (expanded || m.hovering))
        .environment(\.colorScheme, .dark)
        // A styling preference, not a promise of key-window compositor highlights.
        .environment(\.appearsActive, true)
        .animation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.86), value: m.phase)
        .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.86), value: m.hovering)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7), value: m.edge)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: m.level)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: textHeight)
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
private struct PillSurface: View, Animatable {
    let m: Dictation
    var outline: LiquidOutline
    @Binding var textHeight: CGFloat
    var movingLight: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var expanded: Bool { m.phase != .hidden }

    var animatableData: LiquidOutline.AnimatableData {
        get { outline.animatableData }
        set { outline.animatableData = newValue }
    }

    var body: some View {
        let shape = outline
        let frame = shape.mainFrame(in: Dictation.panelSize)
        let mic = shape.orbFrame(in: Dictation.panelSize)
        let pasted = shape.chipFrame(in: Dictation.panelSize)
        ZStack(alignment: .topLeading) {
            GlassSurface(outline: shape, movingLight: movingLight)
            ZStack(alignment: .topLeading) {
                Group {
                    if expanded {
                        panelText
                    } else if m.hovering {
                        (m.armed ? Text("Drag to move") : Text("Hold **fn** to talk"))
                            .font(.system(size: 15)).foregroundStyle(.white)
                            .fixedSize() // the glass grows around it; wrapping while it's narrow looks broken
                    }
                }
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .frame(width: Dictation.panelSize.width, height: Dictation.panelSize.height, alignment: .topLeading)
                .mask(shape.mainBody)
                .transition(.opacity)

                Teeth(open: reduceMotion ? 0.5 : m.level)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 22, height: 22)
                    .frame(width: 38, height: 38)
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
        .frame(width: Dictation.panelSize.width, height: Dictation.panelSize.height)
        .transaction { $0.animation = nil }
    }

    private var panelText: some View {
        Group {
            if m.phase == .failed {
                Text(m.error).foregroundStyle(.white.opacity(0.6))
            } else {
                Said(settled: m.settled, guessing: m.guessing, level: m.level,
                     trailing: m.phase != .listening ? nil : m.locked ? "tap\u{a0}fn\u{a0}to\u{a0}paste" : "let\u{a0}go\u{a0}to\u{a0}paste")
            }
        }
        .font(.system(size: 22))
        .lineLimit(4).truncationMode(.head)
        .frame(width: 440, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textHeight = $0 }
        .padding(.horizontal, 28).padding(.vertical, 22)
        // Streaming words replace immediately; only the surrounding body changes size.
        .transaction { $0.animation = nil }
    }
}

/// SwiftUI has no public API to stroke a GlassEffectContainer's extracted/merged contour.
private struct GlassSurface: View {
    var outline: LiquidOutline
    var movingLight: Bool
    // The look follows System Settings: Liquid Glass Clear or Tinted is applied by the system glass itself;
    // Reduce transparency makes the panel solid; Increase contrast darkens the smoke and brightens the edge.
    @Environment(\.accessibilityReduceTransparency) private var solid
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        let main = outline.mainFrame(in: Dictation.panelSize)
        let strong = contrast == .increased
        let smoke = LinearGradient(colors: [.black.opacity(strong ? 0.75 : 0.55), .black.opacity(strong ? 0.45 : 0.25)],
                                   startPoint: .init(x: 0.5, y: main.minY / Dictation.panelSize.height),
                                   endPoint: .init(x: 0.5, y: main.maxY / Dictation.panelSize.height))
        // Only one shape is submitted to glass. All subsequent lighting uses that exact union.
        Group {
            if solid {
                outline.fill(Color(white: 0.11))
            } else {
                outline.fill(smoke).glassEffect(.regular.tint(.black.opacity(0.35)), in: outline)
            }
        }
            .overlay {
                outline.stroke(.white.opacity(strong ? 0.7 : 0.24), lineWidth: strong ? 1.5 : 0.8)
            }
            .overlay {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !movingLight)) { timeline in
                    let angle = movingLight ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) * 60 : 225
                    outline.stroke(AngularGradient(
                        stops: [.init(color: .clear, location: 0), .init(color: .clear, location: 0.40),
                                .init(color: .white.opacity(0.9), location: 0.48),
                                .init(color: .white.opacity(0.45), location: 0.51),
                                .init(color: .clear, location: 0.59), .init(color: .clear, location: 1)],
                        center: .init(x: main.midX / Dictation.panelSize.width, y: main.midY / Dictation.panelSize.height),
                        angle: .degrees(angle)), lineWidth: 1.2)
                }
            }
    }
}

/// Public Path unions remove the internal edges before either the glass or border is drawn.
/// The narrow bridges pinch off at 16 pt; separate components then have independent contours.
private struct LiquidOutline: Shape {
    var edge: Dictation.Edge
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

    func mainFrame(in size: CGSize) -> CGRect {
        let w = max(1, width), h = max(1, height)
        let x = edge == .right ? size.width - 10 - w : edge == .left ? 10 : (size.width - w) / 2
        let y = edge == .bottom ? size.height - 10 - h - 54 * max(0, chip) : (size.height - h) / 2
        let dx = (edge == .bottom ? slide : 0), dy = (edge == .bottom ? 0 : -slide)
        // Kept inside the panel, so the hint isn't cut off near a corner.
        return CGRect(x: min(max(x + dx, 10), size.width - 10 - w), y: min(max(y + dy, 10), size.height - 10 - h),
                      width: w, height: h)
    }

    func orbFrame(in size: CGSize) -> CGRect {
        let main = mainFrame(in: size), d = 38 * max(0, orb), gap = max(0, orbGap)
        if edge == .bottom {
            return CGRect(x: main.midX - d / 2, y: main.minY - gap - d, width: d, height: d)
        }
        return CGRect(x: edge == .right ? main.minX - gap - d : main.maxX + gap,
                      y: main.midY - d / 2, width: d, height: d)
    }

    func chipFrame(in size: CGSize) -> CGRect {
        let main = mainFrame(in: size), amount = max(0, chip)
        return CGRect(x: main.midX - 49 * amount, y: main.maxY + max(0, chipGap),
                      width: 98 * amount, height: 30 * amount)
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
                let flatHalf = (edge == .bottom ? main.width : main.height) / 2 - corner
                let bridge = circleBridge(radius: mic.width / 2, gap: max(0, orbGap), flatHalf: flatHalf)
                let transform: CGAffineTransform
                switch edge {
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
                let x = pasted.midX, top = main.maxY - 0.5, bottom = pasted.minY + 0.5
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
    let settled: String
    let guessing: String
    let level: Double
    let trailing: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let x = reduceMotion ? 2 : -0.4 + 1.8 * (t.truncatingRemainder(dividingBy: 1.6) / 1.6)
            let sweep = LinearGradient(
                stops: [.init(color: .white.opacity(0.45), location: 0), .init(color: .white, location: 0.5),
                        .init(color: .white.opacity(0.45), location: 1)],
                startPoint: .init(x: x - 0.15, y: 0.3), endPoint: .init(x: x + 0.15, y: 0.7))
            let gap = guessing.isEmpty || settled.isEmpty ? "" : " "
            let caret = Text(Image(systemName: "poweron"))
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.6 + 0.4 * level))
            // The non-breaking space keeps the dash with its hint, so the hint wraps as one piece.
            Text("""
                \(Text(settled).foregroundStyle(.white))\
                \(Text(gap + guessing).foregroundStyle(sweep))\
                \(caret)\
                \(Text(trailing.map { " —\u{a0}" + $0 } ?? "").foregroundStyle(.white.opacity(0.4)))
                """)
        }
    }
}
