import SwiftUI

/// Everything Yap draws, in one Liquid Glass container so its shapes morph into each other:
/// a small glass droplet docked on a screen edge → "Hold fn" when you hover → the Siri-style panel while
/// you talk → a "Pasted" chip that drips off it → back to the droplet.
/// The panel follows macOS 27's Siri: dark smoky glass, large white text, a glowing caret and a
/// grey trailing hint. Yap's own touch: words still being guessed sit dim with light sweeping
/// through them, the mic buds out of the panel and the caret glows brighter with your voice.
struct Pill: View {
    let m: Dictation
    @Namespace private var glass
    @State private var dripped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var talking: Bool { m.phase == .listening || m.phase == .finishing }

    var body: some View {
        // Glass closer than `spacing` melts together. The orb never gets further than 14, so it stays
        // joined by a liquid neck; the chip ends 18 away, so it stretches out of the panel and breaks free.
        GlassEffectContainer(spacing: 16) {
            VStack(alignment: m.edge.stackAlignment, spacing: dripped ? 18 : -36) {
                HStack(spacing: reduceMotion ? 6 : -8 + 22 * m.level) {
                    if talking && m.edge == .right { orb }
                    switch m.phase {
                    case .hidden where m.hovering: hint.glassEffectID("yap", in: glass)
                    case .hidden: blob.glassEffectID("yap", in: glass)
                    default: panel.glassEffectID("yap", in: glass)
                    }
                    if talking && m.edge != .right { orb }
                }
                .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.55), value: m.level)
                if m.phase == .done { chip.glassEffectID("chip", in: glass) }
            }
        }
        .onChange(of: m.phase) { _, phase in
            dripped = false
            if phase == .done {
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.62).delay(0.1)) { dripped = true }
            }
        }
        .padding(m.edge.inset, 10)
        .frame(width: Dictation.panelSize.width, height: Dictation.panelSize.height, alignment: m.edge.frameAlignment)
        .environment(\.colorScheme, .dark)
        // The panel is never key (it must not steal focus from the app you paste into), so ask for the active glass look.
        .environment(\.appearsActive, true)
        // Glass pops open with a little give, like system menus; Reduce Motion gets a plain cross-fade.
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .bouncy(duration: 0.5, extraBounce: 0.05), value: m.phase)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .bouncy(duration: 0.35), value: m.hovering)
    }

    // A glass droplet at full strength: fading glass with opacity just makes it a grey smudge.
    private var blob: some View {
        Color.clear
            .frame(width: m.edge == .bottom ? 44 : 12, height: m.edge == .bottom ? 12 : 44)
            .smokyGlass(Capsule())
    }

    private var hint: some View {
        Text("Hold **fn** to talk")
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .smokyGlass(Capsule())
    }

    private var panel: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return Group {
            if m.phase == .failed {
                Text(m.error).foregroundStyle(.white.opacity(0.6))
            } else {
                Said(settled: m.settled, guessing: m.guessing, level: m.level,
                     trailing: m.phase != .listening ? nil : m.locked ? "tap\u{a0}fn\u{a0}to\u{a0}paste" : "let\u{a0}go\u{a0}to\u{a0}paste")
            }
        }
        .font(.system(size: 22))
        .lineLimit(4)
        .truncationMode(.head)
        .frame(width: 440, alignment: .leading)
        .frame(minHeight: 34)
        .padding(.horizontal, 28).padding(.vertical, 22)
        // Siri's smoke: darker at the top, clearing towards the bottom so the glass shows through.
        .background(LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom), in: shape)
        .smokyGlass(shape)
    }

    private var orb: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 38, height: 38)
            .smokyGlass(Circle())
            .glassEffectID("orb", in: glass)
            // It has nothing to morph into when it goes, so it would stretch into a stray box; fade it instead.
            .glassEffectTransition(.materialize)
    }

    // Echoes Siri's "Show Results" chip.
    private var chip: some View {
        Label("Pasted", systemImage: "checkmark")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .smokyGlass(Capsule())
    }
}

extension View {
    /// Yap's one material, so every shape can morph and merge with the others (Regular and Clear never mix).
    /// The rim sits inside the glass, before `glassEffect`, so `glassEffectID` still attaches straight to the glass.
    func smokyGlass(_ shape: some InsettableShape) -> some View {
        overlay(Rim(shape: shape)).glassEffect(.regular.tint(.black.opacity(0.3)), in: shape)
    }
}

/// Light catching the glass edge: bright top-left, faint on the sides, a softer bounce bottom-right.
struct Rim<S: InsettableShape>: View {
    let shape: S

    var body: some View {
        shape.strokeBorder(
            LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.06), .white.opacity(0.22)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: 1)
        .blendMode(.plusLighter)
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
