import AppKit
import AVFoundation
import SwiftUI

@main
struct YapApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @AppStorage("locale") private var locale = Dictation.defaultLocale
    @AppStorage("edge") private var edge = Dictation.Edge.right.rawValue

    var body: some Scene {
        MenuBarExtra("Yap", systemImage: "waveform") {
            Text("Hold fn and talk")
            let recent = delegate.yap.recent
            if let last = recent.first {
                Button("Paste last transcript") { delegate.yap.pasteAgain(last) }
                Section("Recent") {
                    ForEach(Array(recent.enumerated()), id: \.offset) { _, text in
                        Button(text.count > 60 ? text.prefix(60) + "…" : text) { delegate.yap.pasteAgain(text) }
                    }
                }
            }
            Divider()
            Picker("Spelling", selection: $locale) {
                Text("British").tag("en_GB")
                Text("American").tag("en_US")
            }
            Picker("Blob", selection: $edge) {
                ForEach(Dictation.Edge.allCases, id: \.rawValue) { Text($0.rawValue.capitalized).tag($0.rawValue) }
            }
            Button("Edit words…") { Words.ensureFile(); NSWorkspace.shared.open(Words.file) }
            Button("Check for updates…") { delegate.updates.check() }
            Divider()
            Button("Quit Yap") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let yap = Dictation()
    let updates = Updates()

    func applicationDidFinishLaunching(_ note: Notification) {
        let args = CommandLine.arguments
        if args.contains("--selftest") { Tidy.selfTest(); Journal.selfTest(); exit(0) }
        if let i = args.firstIndex(of: "--listen") { yap.listenOnce(seconds: Double(args[safe: i + 1] ?? "") ?? 4); return }
        if args.contains("--demo") { yap.demo(); return }
        if args.contains("--keytest") { yap.keyTest(); return }
        updates.start()
        yap.run()
    }
}

/// Hold fn → listen → let go → tidy → paste.
@MainActor @Observable
final class Dictation {
    enum Phase { case hidden, listening, finishing, done, failed }

    /// Which side of the screen the blob docks to.
    enum Edge: String, CaseIterable {
        case right, bottom, left
        var frameAlignment: Alignment { [.right: .trailing, .bottom: .bottom, .left: .leading][self]! }
        var stackAlignment: HorizontalAlignment { [.right: .trailing, .bottom: .center, .left: .leading][self]! }
        var inset: SwiftUI.Edge.Set { [.right: .trailing, .bottom: .bottom, .left: .leading][self]! }
    }
    static let panelSize = CGSize(width: 600, height: 320)

    /// British spelling if your Mac is set to the UK, otherwise American.
    nonisolated static let defaultLocale = Locale.current.region?.identifier == "GB" ? "en_GB" : "en_US"
    private var locale: String { UserDefaults.standard.string(forKey: "locale") ?? Self.defaultLocale }

    var phase = Phase.hidden
    var level = 0.0
    var settled = ""
    var guessing = ""
    var error = ""
    var hovering = false
    /// Double-tapped fn: listening hands-free until fn is tapped again.
    var locked = false
    /// The last five pasted transcripts, newest first, for the menu.
    var recent = Journal.recentTexts(5)
    var edge = Edge(rawValue: UserDefaults.standard.string(forKey: "edge") ?? "") ?? .right

    private let listener = Listener()
    @ObservationIgnored private let fnKey = FnKey()
    @ObservationIgnored private var tapWait: Task<Void, Never>?
    @ObservationIgnored private var dryRun = false // tests: never paste
    private var startTask: Task<Void, Error>?
    private var pressedAt = Date()
    // For the journal: one dictation's id, timings and loudest moment.
    @ObservationIgnored private var id = ""
    @ObservationIgnored private var readyAt: Date?
    @ObservationIgnored private var firstWordsAt: Date?
    @ObservationIgnored private var releasedAt = Date()
    @ObservationIgnored private var peak = 0.0
    @ObservationIgnored private var frontApp = ""
    @ObservationIgnored private lazy var panel = makePanel()

    func run() {
        // Accessibility: to see fn from any app, and to paste with ⌘V.
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        fnKey.onChange = { [weak self] down in MainActor.assumeIsolated { down ? self?.keyDown() : self?.keyUp() } }
        fnKey.onOtherKey = { [weak self] in MainActor.assumeIsolated { self?.cancel() } }
        // The tap can only be made once Accessibility is granted, so keep trying until it is.
        if !fnKey.install() {
            Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
                MainActor.assumeIsolated { if self?.fnKey.install() ?? true { t.invalidate() } }
            }
        }
        // The panel ignores the mouse so it never blocks clicks; hover is worked out from the pointer position.
        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor in self?.updateHover() }
        }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, let e = Edge(rawValue: UserDefaults.standard.string(forKey: "edge") ?? ""), e != self.edge else { return }
                self.edge = e; self.position()
            }
        }
        position()
        panel.orderFrontRegardless()
        Journal.reap()
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in Journal.reap() }
    }

    private func updateHover() {
        let p = NSEvent.mouseLocation, f = panel.frame
        let zone: NSRect = switch edge {
        case .right: NSRect(x: f.maxX - 48, y: f.midY - 60, width: 48, height: 120)
        case .left: NSRect(x: f.minX, y: f.midY - 60, width: 48, height: 120)
        case .bottom: NSRect(x: f.midX - 70, y: f.minY, width: 140, height: 40)
        }
        let over = phase == .hidden && zone.contains(p)
        if over != hovering { hovering = over }
    }

    func keyDown() {
        if phase == .listening {
            if let wait = tapWait { wait.cancel(); tapWait = nil; locked = true } // second tap: stay open
            else if locked { finish() }                                             // tap again to paste
            return
        }
        guard phase == .hidden else { return }
        pressedAt = Date(); settled = ""; guessing = ""; level = 0
        id = UUID().uuidString; readyAt = nil; firstWordsAt = nil; peak = 0
        frontApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        let recordTo = Journal.audioURL(for: id)
        hovering = false
        phase = .listening
        let words = Words.load()
        startTask = Task {
            try await listener.start(
                locale: locale, terms: words.terms, recordTo: recordTo,
                onLevel: { v in Task { @MainActor in self.level = self.level * 0.6 + v * 0.4; self.peak = max(self.peak, v) } },
                onText: { s, g in Task { @MainActor in
                    if self.firstWordsAt == nil, !(s + g).isEmpty { self.firstWordsAt = Date() }
                    self.settled = s; self.guessing = g
                } })
            readyAt = Date()
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
        locked = false
        phase = .finishing; level = 0; releasedAt = Date()
        Task {
            do { try await startTask?.value } catch {
                log(outcome: "error", raw: "", text: "", error: error.localizedDescription)
                return fail(error.localizedDescription)
            }
            let raw = await listener.stop()
            let text = Tidy.clean(raw, replacements: Words.load().replacements)
            guard !text.isEmpty else { log(outcome: "empty", raw: raw, text: ""); return hide() }
            log(outcome: "pasted", raw: raw, text: text)
            recent = Array(([text] + recent).prefix(5))
            settled = text; guessing = ""
            if !dryRun { paste(text + " ") }
            phase = .done
            try? await Task.sleep(for: .milliseconds(900))
            hide()
        }
    }

    /// fn was used as a modifier (fn+← and so on), not to dictate: drop what was heard.
    private func cancel() { discard(outcome: "cancelled") }

    private func discard(outcome: String) {
        guard phase == .listening else { return }
        tapWait?.cancel(); tapWait = nil; locked = false
        phase = .finishing; level = 0; releasedAt = Date()
        Task {
            _ = try? await startTask?.value
            _ = await listener.stop()
            log(outcome: outcome, raw: "", text: "")
            if let f = Journal.audioURL(for: id) { try? FileManager.default.removeItem(at: f) }
            hide()
        }
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
        if let f = Journal.audioURL(for: id), FileManager.default.fileExists(atPath: f.path) { e["audio"] = f.lastPathComponent }
        Journal.write(e)
        Journal.reap()
    }

    private func fail(_ message: String) {
        error = message; phase = .failed
        Task { try? await Task.sleep(for: .seconds(3)); hide() }
    }

    // Back to the blob.
    private func hide() { phase = .hidden }

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
        pb.setString(text, forType: .string)
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
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.contentView = NSHostingView(rootView: Pill(m: self))
        return p
    }

    /// Docks the panel to the chosen edge of the main screen.
    private func position() {
        guard let f = NSScreen.screens.first?.visibleFrame else { return }
        let s = Self.panelSize
        let origin = switch edge {
        case .right: NSPoint(x: f.maxX - s.width, y: f.midY - s.height / 2)
        case .left: NSPoint(x: f.minX, y: f.midY - s.height / 2)
        case .bottom: NSPoint(x: f.midX - s.width / 2, y: f.minY)
        }
        panel.setFrameOrigin(origin)
    }

    // MARK: checks you can run from the terminal

    /// `Yap --listen 4`: records from the mic for N seconds and prints the tidied text.
    func listenOnce(seconds: Double) {
        Task {
            do {
                try await listener.start(locale: locale, terms: Words.load().terms, onLevel: { _ in }, onText: { _, _ in })
                try await Task.sleep(for: .seconds(seconds))
                let raw = await listener.stop()
                print("raw:  \(raw)\ntidy: \(Tidy.clean(raw, replacements: Words.load().replacements))")
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
        if let e = CommandLine.arguments.compactMap(Edge.init(rawValue:)).first { edge = e }
        panel.orderFrontRegardless(); position()
        let said = "So I think we should just merge the providers and the harnesses pages into one".split(separator: " ")
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            hovering = true
            try? await Task.sleep(for: .milliseconds(1200))
            hovering = false; phase = .listening
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
            exit(0)
        }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
