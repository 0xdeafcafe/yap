import AppKit
import AVFoundation
import FoundationModels
import SwiftUI

@main
struct YapApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    /// The wind-up teeth, drawn in one colour so macOS tints them to suit the menu bar.
    private static let menuBarIcon: NSImage = {
        let image = Bundle.main.image(forResource: "MenuBarIcon") ?? NSImage(systemSymbolName: "mouth", accessibilityDescription: nil)!
        image.isTemplate = true
        image.accessibilityDescription = "Yap"
        return image
    }()

    var body: some Scene {
        MenuBarExtra {
            Text("Hold fn and talk")
            let recent = delegate.yap.recent
            if let last = recent.first {
                Button("Paste last transcript") { delegate.yap.pasteAgain(last) }
                Section("Recent") {
                    ForEach(Array(recent.enumerated()), id: \.offset) { _, text in
                        // One line each, even when formatting put line breaks or bullets in it.
                        let line = text.split(whereSeparator: \.isNewline).joined(separator: " ")
                        Button(line.count > 60 ? line.prefix(60) + "…" : line) { delegate.yap.pasteAgain(text) }
                    }
                }
            }
            Divider()
            SettingsButton(title: "History…", pane: .history).keyboardShortcut("y") // ⌘H is Hide; ⌘Y is History in Safari
            SettingsButton(title: "Settings…", pane: .general).keyboardShortcut(",")
            OnboardingButton()
            Button("Check for Updates…") { delegate.updates.check() }
            Divider()
            Button("Quit Yap") { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: {
            MenuBarLabel(icon: Self.menuBarIcon)
        }

        Window("Yap", id: "settings") { SettingsView(m: delegate.yap, checkForUpdates: delegate.updates.check) }
            .defaultSize(width: 760, height: 560)
            .windowToolbarStyle(.unified)
            .defaultLaunchBehavior(.suppressed) // the menu opens it

        Window("Welcome to Yap", id: "onboarding") { Onboarding() }
            .windowStyle(.hiddenTitleBar)
            .windowResizability(.contentSize)
            .windowBackgroundDragBehavior(.enabled)
            .defaultLaunchBehavior(.suppressed) // the first launch opens it, below
    }
}

/// Set Up Yap… in the menu: the first-launch pages again.
private struct OnboardingButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View { Button("Set Up Yap…") { NSApp.activate(); openWindow(id: "onboarding") } }
}

/// The menu bar icon. `--settings` opens the window from here, the first view SwiftUI draws.
private struct MenuBarLabel: View {
    let icon: NSImage
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Image(nsImage: icon)
            .task {
                if CommandLine.arguments.contains("--settings") { openWindow(id: "settings") }
                // The first time, or when asked: never for test runs from the command line.
                else if CommandLine.arguments.contains("--onboarding")
                            || (!UserDefaults.standard.bool(forKey: "onboarded") && CommandLine.arguments.count == 1) {
                    NSApp.activate(); openWindow(id: "onboarding")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Privacy.openSettings)) { _ in NSApp.activate(); openWindow(id: "settings") }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let yap = Dictation()
    let updates = Updates()

    func applicationDidFinishLaunching(_ note: Notification) {
        let args = CommandLine.arguments
        if args.contains("--spot-test") { Spot.selfTest(); exit(0) }
        if args.contains("--selftest") { Tidy.selfTest(); Journal.selfTest(); Learn.selfTest(); Context.selfTest(); Privacy.selfTest(); Spot.selfTest(); Caret.selfTest(); ClickRecording.selfTest(); FnKey.selfTest(); Said.selfTest(); Polish.selfTest(); Structure.selfTest(); Rich.selfTest(); Language.selfTest(); Heavy.selfTest(); exit(0) }
        if let i = args.firstIndex(of: "--structure") { // the whole-dictation shape pass: --structure "We need three things. Milk. Eggs. Bread."
            let text = args[safe: i + 1] ?? ""
            Task {
                _ = await Structure.layout("Warm up. One. Two. Three.", timeout: .seconds(20))
                let started = Date()
                let out = await Structure.layout(text, timeout: .seconds(20))
                print(out.map { "laid out:\n\($0)" } ?? "kept (no list, or the model said nothing usable)")
                print("\(Int(Date().timeIntervalSince(started) * 1000)) ms")
                exit(0)
            }
            return
        }
        if let i = args.firstIndex(of: "--polish") { // try the model on some text: --polish "um so what I mean is"
            let text = args[safe: i + 1] ?? ""
            Task {
                let started = Date()
                let out = await Polish.run(Tidy.clean(text), timeout: .seconds(20))
                print(out.map { "polished: \($0)" } ?? "kept: \(Tidy.clean(text)) (model \(Polish.available ? "changed words or failed" : "unavailable"))")
                print("\(Int(Date().timeIntervalSince(started) * 1000)) ms")
                exit(0)
            }
            return
        }
        if let i = args.firstIndex(of: "--live-polish") { // as if dictated a sentence every 2 s: --live-polish "um so. what I mean is."
            let raw = args[safe: i + 1] ?? ""
            Task {
                let live = LivePolish(fillers: [])
                var last = ""
                live.onChange = {
                    let now = live.shown.map { "\($0.look):\($0.text)" }.joined(separator: " | ")
                    if now != last { last = now; print("panel: \(now)") }
                }
                Polish.prewarm()
                var heard = ""
                for p in Polish.pieces(raw) {
                    heard += p.text + p.gap
                    live.heard(Tidy.clean(heard))
                    try? await Task.sleep(for: .seconds(2))
                }
                let released = Date(), rules = Tidy.clean(raw)
                let out = await live.finish(rules)
                print("rules:  \(rules)\npasted: \(out)\nwaited \(Int(Date().timeIntervalSince(released) * 1000)) ms after letting go")
                exit(0)
            }
            return
        }
        if let i = args.firstIndex(of: "--heavy"), let input = args[safe: i + 1], let output = args[safe: i + 2] {
            // Heavy on a JSON list of {"input": …} cases, the way a dictation runs: rules, then each sentence tidied
            // (and listed) while you talk, the last after you let go. Writes each case back with "out" and "ms".
            Task {
                var cases = (try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: input)))) as? [[String: Any]] ?? []
                for n in cases.indices {
                    let raw = cases[n]["input"] as? String ?? ""
                    let rules = Tidy.clean(raw, english: true)
                    Heavy.trace = []
                    let live = LivePolish(fillers: [], heavy: true)
                    Polish.prewarm()
                    let pieces = Polish.pieces(rules)
                    live.heard(pieces.dropLast().map { $0.text + $0.gap }.joined())
                    while !live.caughtUp { try? await Task.sleep(for: .milliseconds(20)) }
                    let released = Date()
                    cases[n]["out"] = await live.finish(rules, timeout: .seconds(30))
                    cases[n]["rules"] = rules
                    cases[n]["trace"] = Heavy.trace
                    cases[n]["ms"] = Int(Date().timeIntervalSince(released) * 1000)
                    print("\(n + 1)/\(cases.count)")
                }
                try? JSONSerialization.data(withJSONObject: cases, options: [.prettyPrinted]).write(to: URL(fileURLWithPath: output))
                exit(0)
            }
            return
        }
        if let i = args.firstIndex(of: "--compare-polish"), let input = args[safe: i + 1], let output = args[safe: i + 2] {
            // Old (whole dictation after you let go) against new (a sentence at a time as you talk), on a JSON list of raw texts.
            Task {
                let raws = (try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: input)))) as? [String] ?? []
                let words = Words.load()
                var rows: [[String: Any]] = []
                for (n, raw) in raws.enumerated() {
                    let rules = Tidy.clean(raw, replacements: words.replacements, terms: words.terms, fillers: words.fillers)
                    Polish.prewarm(); try? await Task.sleep(for: .seconds(1))
                    var t = Date()
                    let old = await Polish.run(rules, fillers: words.fillers)
                    let oldMs = Int(Date().timeIntervalSince(t) * 1000)
                    // New: everything but the last sentence was heard while talking; you let go once the model caught up.
                    let pieces = Polish.pieces(rules)
                    let live = LivePolish(fillers: words.fillers)
                    Polish.prewarm()
                    t = Date()
                    live.heard(pieces.dropLast().map { $0.text + $0.gap }.joined())
                    while !live.caughtUp { try? await Task.sleep(for: .milliseconds(20)) }
                    let talkMs = Int(Date().timeIntervalSince(t) * 1000)
                    t = Date()
                    let new = await live.finish(rules)
                    let newMs = Int(Date().timeIntervalSince(t) * 1000)
                    let changed = zip(pieces, Polish.pieces(new)).filter { $0.0.text != $0.1.text }.count
                    rows.append(["raw": raw, "rules": rules, "old": old ?? NSNull(), "old_ms": oldMs, "new": new, "new_wait_ms": newMs,
                                 "model_ms_while_talking": talkMs, "sentences": pieces.count, "sentences_changed": changed,
                                 "words": raw.split(separator: " ").count])
                    print("\(n + 1)/\(raws.count)")
                }
                try? JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted]).write(to: URL(fileURLWithPath: output))
                exit(0)
            }
            return
        }
        if let i = args.firstIndex(of: "--listen") { yap.listenOnce(seconds: Double(args[safe: i + 1] ?? "") ?? 4); return }
        if let i = args.firstIndex(of: "--transcribe") {
            guard args.count > i + 2 else {
                fputs("usage: Yap --transcribe OUTPUT_DIR AUDIO_FILE…\n", stderr)
                exit(2)
            }
            yap.transcribeFiles(out: URL(fileURLWithPath: args[i + 1]), files: args[(i + 2)...].map(URL.init(fileURLWithPath:)))
            return
        }
        if args.contains("--demo") { Live.shared.start(); Live.shared.follow(yap); yap.demo(); return }
        if args.contains("--keytest") { yap.keyTest(); return }
        if args.contains("--learntest") { yap.learnTest(); return }
        if let i = args.firstIndex(of: "--settings") { // the window on its own, to look at: --settings [pane]
            if let pane = args[safe: i + 1].flatMap(SettingsView.Pane.init(rawValue:)) { UserDefaults.standard.set(pane.rawValue, forKey: "settingsPane") }
            NSApp.setActivationPolicy(.regular); NSApp.activate()
            return
        }
        Task { await Language.registerDefault() } // before the first dictation, which is at least a key press away
        Privacy.settleRetention() // before anything reads or trims the log
        updates.start()
        GlobeKey.silence()
        Live.shared.start()
        Live.shared.follow(yap)
        yap.run()
        Privacy.showNoticeOnce()
    }

    func applicationWillTerminate(_ note: Notification) { GlobeKey.restore(); Live.shared.stop() }
}

/// Hold fn → listen → let go → tidy → paste.
@MainActor @Observable
final class Dictation {
    enum Phase { case hidden, listening, finishing, done, failed }

    /// Which side of the screen the blob docks to.
    enum Edge: String, CaseIterable, Codable {
        case right, bottom, left
        var frameAlignment: Alignment { [.right: .trailing, .bottom: .bottom, .left: .leading][self]! }
        var stackAlignment: HorizontalAlignment { [.right: .trailing, .bottom: .center, .left: .leading][self]! }
        var inset: SwiftUI.Edge.Set { [.right: .trailing, .bottom: .bottom, .left: .leading][self]! }
    }

    /// Where the panel opens while you talk: out of the blob, or by the caret, below its line or above it.
    enum Anchor: Equatable { case blob, caret(above: Bool) }

    /// Settings › General › Show while talking.
    enum ShowAt: String, CaseIterable {
        case cursor, blob
        static var current: Self { Self(rawValue: UserDefaults.standard.string(forKey: "showAt") ?? "") ?? .cursor }
    }
    nonisolated static let panelSize = CGSize(width: 600, height: 320)
    /// How many times Yap has pasted: the panel stops saying "let go to paste" once you know.
    static var pastes: Int { UserDefaults.standard.integer(forKey: "pastes") }

    /// Until `Language.registerDefault` has checked your Mac's language: British spelling in the UK, otherwise American.
    nonisolated static let defaultLocale = Locale.current.region?.identifier == "GB" ? "en_GB" : "en_US"
    private var locale: String { Language.current }

    var phase = Phase.hidden
    /// The panel's open, showing what you say. Just after `phase`, once yap knows where to put it.
    var open = false
    var anchor = Anchor.blob
    /// The bubble's size at the caret, from the line it's on.
    var bubble = Caret.Bubble(font: 14)
    var level = 0.0
    var settled = ""
    var guessing = ""
    /// The settled words as the panel shows them: tidied sentences in place, one being rewritten as the model writes it.
    var shown: [(text: String, look: LivePolish.Look)]?
    var error = ""
    /// Near misses of words on screen put right in this dictation, for the panel to mark.
    var fixed: [Context.Fix] = []
    var hovering = false
    /// Double-tapped fn: listening hands-free until fn is tapped again.
    var locked = false
    /// The app in front shows this dictation itself (rush, with its box taking it): Yap shows nothing of its own.
    /// Decided as you press, from what the app last said; undone if it goes.
    var inside = false
    /// The last five pasted transcripts, newest first, for the menu.
    var recent = Journal.recentTexts(5)
    var edge = Spot.load().edge
    var slide: CGFloat = 0
    var pull = CGSize.zero
    var stretch: CGFloat = 1
    var armed = false
    var dragging = false
    var controlHovered = false
    var mousePressed = false
    @ObservationIgnored private var clickRecording = ClickRecording()
    @ObservationIgnored private var clickHold: Task<Void, Never>?
    @ObservationIgnored private var hitRegions: [CGRect] = []
    @ObservationIgnored private var ownedCursor: NSCursor?
    @ObservationIgnored private var spot = Spot.load()
    @ObservationIgnored private var dragOrigin = CGPoint.zero
    @ObservationIgnored private var dragPointer = CGPoint.zero
    @ObservationIgnored private var previousPointer = CGPoint.zero

    private let listener = Listener()
    @ObservationIgnored private let fnKey = FnKey()
    @ObservationIgnored private var tapWait: Task<Void, Never>?
    @ObservationIgnored private var dryRun = false // tests: never paste
    @ObservationIgnored private var cancelled = false
    /// You stopped this dictation: the live socket says so.
    var stopped: Bool { cancelled }
    private var startTask: Task<Void, Error>?
    private var pressedAt = Date()
    // For the journal: one dictation's id, timings and loudest moment.
    @ObservationIgnored private var id = ""
    @ObservationIgnored private var readyAt: Date?
    @ObservationIgnored private var firstWordsAt: Date?
    @ObservationIgnored private var releasedAt = Date()
    @ObservationIgnored private var peak = 0.0
    @ObservationIgnored private(set) var frontApp = ""
    /// Names and terms from the screen and from apps like rush, for this dictation only.
    @ObservationIgnored private var contextWords: [String] = []
    /// What the rules alone made, when the model tidied it further.
    @ObservationIgnored private var rulesText: String?
    /// Tidies each sentence as it settles, when tidying with Apple Intelligence is on.
    @ObservationIgnored private var live: LivePolish?
    @ObservationIgnored private lazy var panel = makePanel()

    func run() {
        // Accessibility: to see fn from any app, and to paste with ⌘V.
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        fnKey.onChange = { [weak self] down in MainActor.assumeIsolated { down ? self?.keyDown() : self?.keyUp() } }
        fnKey.onEscape = { [weak self] in MainActor.assumeIsolated { self?.escape() ?? false } }
        fnKey.onOtherKey = { [weak self] in MainActor.assumeIsolated { self?.cancel() } }
        // The tap can only be made once Accessibility is granted, so keep trying until it is.
        if !fnKey.install() {
            Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
                MainActor.assumeIsolated { if self?.fnKey.install() ?? true { t.invalidate() } }
            }
        }
        // Only the visible controls accept pointer input; the rest of the overlay stays click-through.
        // This sees every move of the pointer anywhere on screen, so a move nowhere near the panel, with nothing
        // lit up from the last one, stops at one rectangle check.
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .flagsChanged]) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.pointerMatters(at: NSEvent.mouseLocation) else { return }
                self.updateHover()
            }
        }
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .flagsChanged, .leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            let consumed = MainActor.assumeIsolated { self?.handlePointer(event) ?? false }
            return consumed ? nil : event
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.position() }
        }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, let e = Edge(rawValue: UserDefaults.standard.string(forKey: "edge") ?? ""), e != self.edge else { return }
                self.edge = e; self.spot.edge = e; self.spot.t = 0.5
                self.spot.save(); self.position()
            }
        }
        AppIcon.clearCustom()
        position()
        panel.orderFrontRegardless()
        Journal.reap(); Journal.forget()
        // The app that was showing the dictation went (rush quit): show it here again.
        Live.shared.onDrop = { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.inside, !Live.shared.showsItself(app: self.frontApp) else { return }
                self.inside = false
                if self.phase != .hidden { self.fade(to: 1, over: 0.2) } // it opened, unseen, at the blob
            }
        }
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in Journal.reap(); Journal.forget() }
    }

    /// Regions come from the rendered, animated shape, in SwiftUI's top-left coordinates.
    func setHitRegions(_ regions: [CGRect]) {
        hitRegions = regions
        if let host = panel.contentView as? PointerHostingView {
            host.controlRegions = regions
            panel.invalidateCursorRects(for: host)
        }
        updateHover()
    }

    /// Whether the pointer at `p` could change the hover: it's over the panel, or the last check left something on
    /// (a hand cursor, the glow, the hint) for this one to put back.
    private func pointerMatters(at p: CGPoint) -> Bool {
        ownedCursor != nil || controlHovered || hovering || armed || !panel.ignoresMouseEvents || panel.frame.contains(p)
    }

    private func updateHover() {
        guard !dragging else { setCursor(.closedHand); return }
        let p = NSEvent.mouseLocation
        let local = CGPoint(x: p.x - panel.frame.minX, y: panel.frame.maxY - p.y)
        let interactive = phase == .hidden || phase == .listening
        let over = interactive && hitRegions.contains { $0.contains(local) }
        armed = phase == .hidden && over && NSEvent.modifierFlags.contains(.command)
        panel.ignoresMouseEvents = !(over || clickRecording.pressed)
        controlHovered = over
        hovering = phase == .hidden && over
        setCursor(over ? (armed ? .openHand : .pointingHand) : nil)
    }

    private func setCursor(_ cursor: NSCursor?) {
        let changed = ownedCursor !== cursor
        let hadCursor = ownedCursor != nil
        ownedCursor = cursor
        if let host = panel.contentView as? PointerHostingView {
            host.pointerCursor = cursor
            if changed { panel.invalidateCursorRects(for: host) }
        }
        // Reassert on movement even if the desired cursor hasn't changed: AppKit may have reset it.
        if let cursor {
            BackgroundCursor.allow(true)
            cursor.set()
        } else if hadCursor {
            NSCursor.arrow.set()
            BackgroundCursor.allow(false)
        }
    }

    private func handlePointer(_ event: NSEvent) -> Bool {
        if event.type == .leftMouseDown && event.window === panel && armed && phase == .hidden {
            dragging = true; hovering = false; setCursor(.closedHand)
            dragOrigin = panel.frame.origin
            dragPointer = NSEvent.mouseLocation; previousPointer = dragPointer
            return true
        }
        if dragging && event.type == .leftMouseDragged {
            let point = NSEvent.mouseLocation
            panel.setFrameOrigin(CGPoint(x: dragOrigin.x + point.x - dragPointer.x,
                                         y: dragOrigin.y + point.y - dragPointer.y))
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                pull = CGSize(width: point.x - previousPointer.x, height: point.y - previousPointer.y)
                stretch = 1 + min(hypot(pull.width, pull.height) / 90, 0.35)
            }
            previousPointer = point
            return true
        }
        if dragging && event.type == .leftMouseUp {
            spot = Spot.snap(NSEvent.mouseLocation, screens: Spot.screens())
            edge = spot.edge; spot.save()
            UserDefaults.standard.set(edge.rawValue, forKey: "edge")
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.65)) {
                pull = .zero; stretch = 1; dragging = false; armed = false
                position(animated: !reduceMotion)
            }
            setCursor(nil)
            updateHover()
            return true
        }
        if event.type == .leftMouseDown && event.window === panel && controlHovered {
            _ = clickRecording.down(at: event.timestamp, listening: phase == .listening)
            mousePressed = true
            clickHold?.cancel()
            clickHold = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, phase == .hidden, controlHovered else { return }
                if clickRecording.hold(at: ProcessInfo.processInfo.systemUptime) == .start { keyDown() }
            }
            panel.ignoresMouseEvents = false // keep the release even as the glass grows away
            return true
        }
        if clickRecording.pressed && event.type == .leftMouseUp {
            clickHold?.cancel(); clickHold = nil
            updateHover()
            let action = clickRecording.up(at: event.timestamp, listening: phase == .listening, inside: controlHovered)
            mousePressed = false
            if action == .latch, phase == .hidden { keyDown(); locked = true }
            if action == .finish { tapWait?.cancel(); tapWait = nil; finish() }
            updateHover()
            return true
        }
        updateHover()
        return false
    }

    func keyDown() {
        if phase == .listening {
            if let wait = tapWait { wait.cancel(); tapWait = nil; locked = true } // second tap: stay open
            else if locked { finish() }                                             // tap again to paste
            return
        }
        guard phase == .hidden, !dragging else { return }
        armed = false; setCursor(nil); panel.ignoresMouseEvents = !clickRecording.pressed
        cancelled = false
        pressedAt = Date(); settled = ""; guessing = ""; level = 0; fixed = []
        id = UUID().uuidString; readyAt = nil; firstWordsAt = nil; peak = 0
        frontApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        // rush shows what you're saying in its message box (it said "shows"), so the pill hides until the dictation's over.
        let rush = Live.shared.showsItself(app: frontApp)
        inside = rush
        if rush { panel.alphaValue = 0 }
        let recordTo = Journal.audioURL(for: id)
        hovering = false
        phase = .listening
        present(at: rush ? .blob : ShowAt.current, visible: !rush)
        let words = Words.load()
        live?.stop(); live = Polish.enabled ? LivePolish(fillers: words.fillers, heavy: Cleanup.current == .heavy) : nil; shown = nil
        Polish.prewarm() // after stopping the last one, which lets its session go
        live?.onChange = { [weak self] in
            guard let self, let live = self.live, self.phase == .listening || self.phase == .finishing else { return }
            self.shown = live.shown
        }
        contextWords = []
        let gather = Learn.enabled ? gatherContext(app: frontApp, id: id) : nil
        startTask = Task {
            try await listener.start(
                locale: locale, terms: words.terms, contextTerms: { await gather?.value ?? [] }, recordTo: recordTo,
                onLevel: { v in Task { @MainActor in self.level = self.level * 0.6 + v * 0.4; self.peak = max(self.peak, v) } },
                onText: { s, g in Task { @MainActor in
                    if self.firstWordsAt == nil, !(s + g).isEmpty { self.firstWordsAt = Date() }
                    if s != self.settled {
                        let ruled = self.rules(s, words)
                        self.fixed = ruled.fixed
                        self.live?.heard(ruled.text)
                    }
                    self.settled = s; self.guessing = g
                } })
            readyAt = Date()
        }
    }

    /// Yap's own cleanup, then near misses of words on screen fixed ("Reddis" with "Redis" there). The lessons are
    /// recorded only once you've finished, as this also runs on the words settled so far.
    private func rules(_ raw: String, _ words: (terms: [String], replacements: [(String, String)], fillers: [String])) -> (text: String, lessons: [Learn.Lesson], fixed: [Context.Fix]) {
        let text = Tidy.clean(raw, replacements: words.replacements, terms: words.terms, fillers: words.fillers,
                              format: Tidy.formatting, english: Language.isEnglish(locale))
        guard Learn.enabled, !contextWords.isEmpty else { return (text, [], []) }
        let isKnown = Context.knownCheck(for: text, yours: Words.known(words), language: locale)
        return Context.fixes(text, context: contextWords, isKnown: isKnown)
    }

    /// Reads the focused window and what apps sent for it, while the mic starts, and keeps the words worth hearing.
    private func gatherContext(app: String, id: String) -> Task<[String], Never> {
        let client = Live.shared.words(for: app)
        let language = locale
        return Task {
            async let screen = Context.readScreen()
            // Yap's own recent words: one still on screen that's a near miss of another is an old mishearing.
            async let said = Task.detached(priority: .userInitiated) {
                Set(Journal.recentTexts(50).flatMap { $0.split(whereSeparator: { !($0.isLetter || $0.isNumber) }).map { $0.lowercased() } })
            }.value
            let hints = Context.hints(client: client, screen: await screen, yapSaid: await said, language: language)
            if self.id == id { self.contextWords = hints }
            return hints
        }
    }

    func keyUp() {
        guard phase == .listening, !locked, tapWait == nil else { return }
        if Date().timeIntervalSince(pressedAt) <= 0.3 {
            // A quick tap is either an accident or the first half of a double tap: wait to see which.
            tapWait = Task {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                tapWait = nil
                discard(outcome: "tap")
            }
            return
        }
        finish()
    }

    private func finish() {
        locked = false; controlHovered = false; setCursor(nil)
        phase = .finishing; level = 0; releasedAt = Date()
        Task {
            do { try await startTask?.value } catch {
                if cancelled { _ = await listener.stop(); completeDiscard("cancelled"); return }
                listener.cancelCapture() // don't leave the mic on after a failed start
                log(outcome: "error", raw: "", text: "", error: error.localizedDescription)
                return fail(error.localizedDescription)
            }
            let raw = await listener.stop()
            guard !cancelled else { completeDiscard("cancelled"); return }
            let words = Words.load()
            let ruled = rules(raw, words)
            var text = ruled.text
            fixed = ruled.fixed
            contextWords = []
            rulesText = nil
            // Its shape is asked for now, while the sentences are tidied, and used after.
            let shape = Tidy.formatting && Polish.enabled ? Structure.ask(text) : nil
            if let live {
                live.onChange = { [weak self, weak live] in
                    guard let self, let live, self.phase == .finishing else { return }
                    self.shown = live.shown
                }
                self.live = nil
                let polished = await live.finish(text)
                if polished != text { rulesText = text; text = polished }
            }
            // Its shape, once there's all of it: sentences that are a list go on lines of their own.
            if let shape, let shaped = await Structure.apply(shape, to: text) {
                if rulesText == nil { rulesText = text }
                text = shaped
            }
            guard !cancelled else { completeDiscard("cancelled"); return }
            // Bold goes to the app as real bold; everywhere else (the panel, history, rush) it's plain.
            let formatted = text
            text = Rich.plain(text)
            guard !text.isEmpty else { log(outcome: "empty", raw: raw, text: ""); return hide() }
            // Paste first: the panel only redraws after this, and the history, learning and tidying the
            // recordings folder all touch the disk, so they wait until the text is in.
            settled = text; guessing = ""; shown = nil
            phase = .done
            // At the caret the words land right by the bubble, so it gets out of their way as they do.
            let atCaret = anchor != .blob
            if atCaret { fade(to: 0, over: 0.12) }
            Live.shared.publish(now: true) // before the paste, so an app showing the dictation knows the paste is it
            // An app that puts the dictation in its own box (rush) says so: then there's nothing to paste.
            let taken = await Live.shared.taken(text, app: frontApp)
            if !dryRun, !taken { paste(formatted + " "); UserDefaults.standard.set(Dictation.pastes + 1, forKey: "pastes") }
            log(outcome: "pasted", raw: raw, text: text)
            if !ruled.lessons.isEmpty { Learn.record(ruled.lessons) }
            if !dryRun, !taken { Learn.watch(pasted: text + " ") }
            recent = Array(([text] + recent).prefix(5))
            try? await Task.sleep(for: .milliseconds(atCaret ? 150 : 900))
            hide(faded: atCaret)
        }
    }

    /// Escape cancels both active recording and a pending paste; idle Escape passes through.
    private func escape() -> Bool {
        let pendingClick = clickRecording.pressed
        guard phase == .listening || phase == .finishing || pendingClick else { return false }
        clickHold?.cancel(); clickHold = nil; clickRecording = ClickRecording(); mousePressed = false
        tapWait?.cancel(); tapWait = nil; locked = false
        cancelled = true
        startTask?.cancel()
        listener.cancelCapture()
        if phase == .listening { discard(outcome: "cancelled") }
        updateHover()
        return true
    }

    /// fn used as a modifier: drop the recording and preserve the other shortcut.
    private func cancel() { discard(outcome: "cancelled") }

    private func discard(outcome: String) {
        guard phase == .listening else { return }
        cancelled = true
        tapWait?.cancel(); tapWait = nil; locked = false
        startTask?.cancel(); listener.cancelCapture()
        phase = .finishing; level = 0; releasedAt = Date()
        Task {
            _ = try? await startTask?.value
            _ = await listener.stop()
            completeDiscard(outcome)
        }
    }

    private func completeDiscard(_ outcome: String) {
        // Discard audio even if the retention preference changed during the recording.
        try? FileManager.default.removeItem(at: Journal.audioDir.appending(path: "\(id).wav"))
        log(outcome: outcome, raw: "", text: "")
        settled = ""; guessing = ""; shown = nil; contextWords = []; fixed = []
        live?.stop(); live = nil
        hide()
    }

    private func log(outcome: String, raw: String, text: String, error: String? = nil) {
        let ms = { (a: Date, b: Date?) -> Any in b.map { Int($0.timeIntervalSince(a) * 1000) } ?? NSNull() }
        var e: [String: Any] = [
            "id": id, "at": ISO8601DateFormatter().string(from: pressedAt), "outcome": outcome,
            "app": frontApp, "locale": locale, "raw": raw, "text": text,
            "held_ms": ms(pressedAt, releasedAt), "audio_s": (listener.audioSeconds * 10).rounded() / 10,
            "ready_ms": ms(pressedAt, readyAt), "first_words_ms": ms(pressedAt, firstWordsAt),
            "finish_ms": ms(releasedAt, Date()), "peak_level": (peak * 100).rounded() / 100,
        ]
        if let error { e["error"] = error }
        if let rulesText, outcome == "pasted" { e["rules_text"] = rulesText }
        // Only the ones that made it into what was pasted: the model may have rewritten the sentence around one.
        let kept = fixed.filter { text.contains($0.now) }
        if outcome == "pasted", !kept.isEmpty { e["fixed"] = kept.map { ["was": $0.was, "now": $0.now] } }
        if let f = Journal.audioURL(for: id), FileManager.default.fileExists(atPath: f.path) { e["audio"] = f.lastPathComponent }
        Journal.write(e)
        Journal.reap()
    }

    private func fail(_ message: String) {
        error = message; phase = .failed
        if inside { inside = false; fade(to: 1, over: 0.2) } // an error's yap's to show, whoever was showing the words
        Task { try? await Task.sleep(for: .seconds(3)); hide() }
    }

    // Back to the blob.
    /// `faded`: the bubble at the caret has already gone, so there's no shrinking back into the dot to wait for.
    private func hide(faded: Bool = false) {
        phase = .hidden; open = false; inside = false
        if anchor != .blob { backToBlob(faded: faded) }
        else if panel.alphaValue < 1 { fade(to: 1, over: 0.25) }
    }

    /// Opens the panel by the caret, if you want it there and the app says where it is; otherwise out of the blob.
    /// It appears there on its own rather than flying over from the blob: the caret's often a screen away from the
    /// edge, and the panel should be where you're already looking, the moment you start.
    /// `visible` is false while rush draws the dictation itself: the panel opens, unseen, at the blob.
    private func present(at place: ShowAt, visible: Bool) {
        let id = self.id
        func atTheBlob() {
            atBlob()
            if visible && panel.alphaValue < 1 { fade(to: 1, over: 0) } // a dot still fading off the last caret
            open = true
        }
        guard place == .cursor else { return atTheBlob() }
        Task {
            let found = await Caret.find()
            guard self.id == id, phase != .hidden else { return }
            guard let found, let placed = caretPlacement(found) else { return atTheBlob() }
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            // Out of sight: the blob leaves its edge, and the glass becomes a dot on the caret.
            fade(to: 0, over: 0)
            unanimated { anchor = .caret(above: placed.above); bubble = placed.bubble }
            panel.setFrameOrigin(placed.frame.origin)
            // A frame of the dot first, so the spring grows the panel out of it.
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(30)) }
            guard self.id == id, phase != .hidden else { return } // hide() is already taking it back
            fade(to: 1, over: reduceMotion ? 0.15 : 0.08)
            open = true
        }
    }

    private func unanimated(_ change: () -> Void) {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t, change)
    }

    /// Through the animator even when instant, so it replaces a fade that's still running.
    private func fade(to alpha: CGFloat, over seconds: TimeInterval) {
        NSAnimationContext.runAnimationGroup { $0.duration = seconds; panel.animator().alphaValue = alpha }
    }

    /// The window back at the edge (no animation: it's only ever done out of sight, or before opening at the blob).
    private func atBlob() {
        guard anchor != .blob else { return }
        unanimated { anchor = .blob }
        position()
    }

    /// The panel shrinks back into its dot on the caret, fades, and the blob comes back to its edge.
    private func backToBlob(faded: Bool) {
        let id = self.id
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion || faded ? 0 : 380))
            guard self.id == id, phase == .hidden else { return } // a new dictation has the window now
            fade(to: 0, over: faded ? 0 : 0.12)
            try? await Task.sleep(for: .milliseconds(faded ? 20 : 130))
            guard self.id == id, phase == .hidden else { return }
            atBlob()
            fade(to: 1, over: 0.25)
        }
    }

    /// The window's frame by a caret Accessibility gave, or nil if it's not on any display.
    private func caretPlacement(_ ax: CGRect) -> (frame: CGRect, above: Bool, bubble: Caret.Bubble)? {
        guard let main = NSScreen.screens.first else { return nil } // Accessibility measures from the menu bar's display
        let caret = Caret.flip(ax, mainHeight: main.frame.height)
        guard let visible = Caret.screen(for: caret, in: NSScreen.screens.map(\.visibleFrame)) else { return nil }
        let bubble = Caret.Bubble(line: caret.height)
        let placed = Caret.place(caret, visible: visible, bubble: bubble)
        return (placed.frame, placed.above, bubble)
    }

    /// Puts text in a text box of Yap's own (never another app's), corrects it the way you would, and checks
    /// Yap learns from reading it back through Accessibility. Then forgets what it learned.
    func learnTest() {
        let view = NSTextView(frame: .init(x: 0, y: 0, width: 300, height: 100))
        let window = NSWindow(contentRect: .init(x: -4000, y: -4000, width: 300, height: 100), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view; window.alphaValue = 0.01; window.orderFrontRegardless()
        let pasted = "ping lang watch now "
        view.string = "Hi. " + pasted; view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
        let saved = try? String(contentsOf: Words.learnedFile, encoding: .utf8)
        let pending = UserDefaults.standard.object(forKey: "learnPending")
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            func find(_ e: AXUIElement) -> AXUIElement? {
                var role: CFTypeRef?, kids: CFTypeRef?
                AXUIElementCopyAttributeValue(e, kAXRoleAttribute as CFString, &role)
                if role as? String == kAXTextAreaRole { return e }
                AXUIElementCopyAttributeValue(e, kAXChildrenAttribute as CFString, &kids)
                return (kids as? [AXUIElement] ?? []).lazy.compactMap(find).first
            }
            guard let field = find(AXUIElementCreateApplication(getpid())) else { print("FAIL: can't see the text box"); exit(1) }
            Learn.watch(pasted: pasted, field: field, every: 0.2)
            try? await Task.sleep(for: .seconds(1))
            view.string = "Hi. ping LangWatch now "
            try? await Task.sleep(for: .seconds(3.5))
            let learned = (try? String(contentsOf: Words.learnedFile, encoding: .utf8)) ?? ""
            let ok = learned.split(separator: "\n").contains("LangWatch")
            // Put learned.txt back as it was.
            UserDefaults.standard.set(pending, forKey: "learnPending")
            if let saved { try? saved.write(to: Words.learnedFile, atomically: true, encoding: .utf8) } else { try? FileManager.default.removeItem(at: Words.learnedFile) }
            print(ok ? "PASS: learned LangWatch from a correction" : "FAIL: learned.txt had \(learned.debugDescription)")
            exit(ok ? 0 : 1)
        }
    }

    /// Puts the text on the clipboard, presses ⌘V, then puts your clipboard back as it was.
    /// From the menu: wait for it to close so the app you were in has the keyboard again, then paste.
    func pasteAgain(_ text: String) {
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            paste(text + " ")
        }
    }

    private func paste(_ text: String) {
        let pb = NSPasteboard.general
        let saved = (pb.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types { if let d = item.data(forType: type) { copy.setData(d, forType: type) } }
            return copy
        }
        pb.clearContents()
        // Formatted: HTML for apps that take it, with real bold and lists; plain for the rest (terminals, code).
        if Rich.isFormatted(text) {
            let item = NSPasteboardItem()
            item.setString(Rich.html(text), forType: .html)
            item.setString(Rich.plain(text), forType: .string)
            pb.writeObjects([item])
        } else {
            pb.setString(text, forType: .string)
        }
        let src = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: down) // 9 = V
            e?.flags = .maskCommand
            e?.post(tap: .cghidEventTap)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            pb.clearContents()
            if !saved.isEmpty { pb.writeObjects(saved) }
        }
    }

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: Self.panelSize),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.ignoresMouseEvents = true
        p.acceptsMouseMovedEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let host = PointerHostingView(rootView: Pill(m: self))
        host.pointerChanged = { [weak self] in self?.updateHover() }
        p.contentView = host
        return p
    }

    /// Keep the saved display and offset; a disconnected display falls back to the main display.
    private func position(animated: Bool = false) {
        guard anchor == .blob, let visible = Spot.visible(for: spot, in: Spot.screens()) else { return }
        let placement = Spot.panelFrame(spot, visible)
        slide = placement.slide
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                panel.animator().setFrameOrigin(placement.frame.origin)
            }
        } else { panel.setFrameOrigin(placement.frame.origin) }
    }

    // MARK: checks you can run from the terminal

    /// For benchmarks: each recording through the recogniser and cleanup, as `out/raw/<name>.txt` and
    /// `out/clean/<name>.txt`, with timings in `out/timing.jsonl`. Nothing is printed but counts.
    func transcribeFiles(out: URL, files: [URL]) {
        Task {
            let words = Words.load()
            for dir in ["raw", "clean"] { try? FileManager.default.createDirectory(at: out.appending(path: dir), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
            var timings = ""
            var failures = 0
            for (n, file) in files.enumerated() {
                let name = file.deletingPathExtension().lastPathComponent
                do {
                    let r = try await Listener.transcribe(file, locale: locale, terms: words.terms)
                    let clean = Tidy.clean(r.text, replacements: words.replacements, terms: words.terms, fillers: words.fillers, english: Language.isEnglish(locale))
                    try r.text.write(to: out.appending(path: "raw/\(name).txt"), atomically: true, encoding: .utf8)
                    try clean.write(to: out.appending(path: "clean/\(name).txt"), atomically: true, encoding: .utf8)
                    let seconds = (try? AVAudioFile(forReading: file)).map { Double($0.length) / $0.fileFormat.sampleRate } ?? 0
                    let row: [String: Any] = ["name": name, "audio_s": seconds, "ready_ms": r.readyMs, "total_ms": r.totalMs]
                    timings += String(decoding: try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]), as: UTF8.self) + "\n"
                    print("\(n + 1)/\(files.count)")
                } catch { failures += 1; print("\(n + 1)/\(files.count) failed") }
            }
            do { try timings.write(to: out.appending(path: "timing.jsonl"), atomically: true, encoding: .utf8) }
            catch { failures += 1 }
            exit(failures == 0 ? 0 : 1)
        }
    }

    func listenOnce(seconds: Double) {
        Task {
            do {
                try await listener.start(locale: locale, terms: Words.load().terms, onLevel: { _ in }, onText: { _, _ in })
                try await Task.sleep(for: .seconds(seconds))
                let raw = await listener.stop()
                let words = Words.load()
                print("raw:  \(raw)\ntidy: \(Tidy.clean(raw, replacements: words.replacements, terms: words.terms, fillers: words.fillers, format: Tidy.formatting, english: Language.isEnglish(locale)))")
            } catch { print("error: \(error)") }
            exit(0)
        }
    }

    /// `Yap --keytest`: fakes fn presses to check single taps, double taps and holds. Pastes nothing.
    func keyTest() {
        func press(_ ms: Int) async { keyDown(); try? await Task.sleep(for: .milliseconds(ms)); keyUp() }
        func wait(_ ms: Int) async { try? await Task.sleep(for: .milliseconds(ms)) }
        dryRun = true
        Task {
            await press(80); await wait(600)
            precondition(phase != .listening && !locked, "a single tap should be dropped")
            await wait(1500)
            await press(80); await wait(120); await press(80); await wait(600)
            precondition(phase == .listening && locked, "a double tap should stay open")
            keyDown()
            precondition(phase == .finishing && !locked, "a tap while open should finish")
            await wait(2500)
            precondition(phase == .hidden || phase == .done, "should be done")
            print("key self-test passed")
            exit(0)
        }
    }

    /// `Yap --demo`: plays a fake dictation so you can see the pill without speaking.
    func demo() {
        if let e = CommandLine.arguments.compactMap(Edge.init(rawValue:)).first { edge = e; spot.edge = e }
        panel.orderFrontRegardless(); position()
        let said = "I knew you were trouble when you walked in (oh), So shame on me now, Flew me to places I'd never been, 'Til you put me down, oh, I knew you were trouble when you walked in, So shame on me now, Flew me to places I'd never been, yeah, Now I'm lyin' on the cold hard ground, Oh, oh (yeah), Trouble, trouble, trouble, Oh, oh, Trouble, trouble, trouble".split(separator: " ")
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            hovering = true
            try? await Task.sleep(for: .milliseconds(1200))
            hovering = false; phase = .listening; open = true
            for (i, w) in said.enumerated() {
                level = Double.random(in: 0.35...0.95)
                guessing = said[max(0, i - 2)...i].joined(separator: " ")
                settled = said[..<max(0, i - 2)].joined(separator: " ")
                try? await Task.sleep(for: .milliseconds(w.count * 45 + 160))
            }
            level = 0; phase = .finishing
            try? await Task.sleep(for: .milliseconds(500))
            settled = said.joined(separator: " ") + "."; guessing = ""; phase = .done
            try? await Task.sleep(for: .milliseconds(1500))
            hide()
            try? await Task.sleep(for: .milliseconds(1500))
            Live.shared.stop()
            exit(0)
        }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
