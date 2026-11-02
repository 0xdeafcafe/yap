import Speech
import SwiftUI

/// One window for everything you can change, and your history: a sidebar on the left, the way
/// System Settings does it, so macOS draws it in Liquid Glass.
struct SettingsView: View {
    let m: Dictation
    let checkForUpdates: () -> Void
    @AppStorage("settingsPane") private var pane = Pane.general
    @State private var search = ""
    @State private var entries = Journal.entries()

    enum Pane: String, CaseIterable, Identifiable {
        case general, words, privacy, history
        var id: Self { self }
        var title: String { rawValue.capitalized }
        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .words: "character.book.closed"
            case .privacy: "hand.raised"
            case .history: "clock.arrow.circlepath"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: Binding($pane)) { Label($0.title, systemImage: $0.symbol) }
                .navigationSplitViewColumnWidth(min: 170, ideal: 180, max: 220)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch pane {
                case .general: GeneralPane(checkForUpdates: checkForUpdates).navigationTitle("General")
                case .words: WordsPane().navigationTitle("Words")
                case .privacy: PrivacyPane(m: m).navigationTitle("Privacy")
                case .history: HistoryView(entries: $entries, search: search).navigationTitle("History")
                }
            }
            // Scrolled content fades softly under the glass toolbar instead of meeting a hard line.
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
        // On every pane, so the toolbar keeps one height and the window never changes shape.
        // It searches your history from anywhere: typing opens History.
        .searchable(text: $search, placement: .toolbar, prompt: entries.isEmpty ? "Search" : "Search \(entries.count) dictations")
        .onChange(of: search) { if !search.isEmpty { pane = .history } }
        .onChange(of: m.recent) { entries = Journal.entries() }
        .frame(minWidth: 680, minHeight: 460)
    }
}

private struct GeneralPane: View {
    let checkForUpdates: () -> Void
    @AppStorage("locale") private var locale = Dictation.defaultLocale
    @AppStorage("edge") private var edge = Dictation.Edge.right.rawValue
    @AppStorage("appIcon") private var appIcon = AppIcon.cream.rawValue
    @AppStorage("formatting") private var formatting = false
    @AppStorage("cleanup") private var cleanup = Cleanup.current.rawValue
    /// Every language Apple's recogniser can dictate; until it answers, just the one you have.
    @State private var languages: [String] = []
    @State private var download: Progress?
    @State private var downloadFailed = false

    var body: some View {
        let english = Language.isEnglish(locale), polishable = Polish.available && Language.modelSupports(locale)
        Form {
            Section {
                Picker(selection: $locale) {
                    ForEach(languages.contains(locale) ? languages : [locale] + languages, id: \.self) { Text(Language.name($0)).tag($0) }
                } label: {
                    Text("Language")
                    if let download {
                        ProgressView(download).progressViewStyle(.linear)
                    } else if downloadFailed {
                        Text("Couldn't download it. Yap will try again when you dictate.")
                    }
                }
                Toggle(isOn: $formatting) {
                    Text("Formatting")
                    Text(english ? "Say “new line”, “bullet”, or “code npm test end code”."
                                 : "Say “new line”, “bullet”, or “code npm test end code”, in English.")
                }
                let level = Cleanup(rawValue: cleanup) ?? .medium
                LabeledContent {
                    Slider(value: Binding(get: { Double(Cleanup.allCases.firstIndex(of: level) ?? 1) },
                                          set: { cleanup = Cleanup.allCases[Int($0.rounded())].rawValue }),
                           in: 0...2, step: 1) { EmptyView() } minimumValueLabel: { Text("Light") } maximumValueLabel: { Text("Heavy") }
                        .frame(width: 200)
                } label: {
                    Text("Cleanup")
                    Text(Self.describe(level, polishable: polishable, english: english, language: Language.name(locale)))
                }
            }
            .task { languages = await Language.dictatable() }
            .task(id: locale) { await fetch(locale) }
            Section {
                Picker("Blob", selection: $edge) {
                    ForEach(Dictation.Edge.allCases, id: \.rawValue) { Text($0.rawValue.capitalized).tag($0.rawValue) }
                }
                Picker("App icon", selection: $appIcon) {
                    ForEach(AppIcon.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
            } footer: {
                Text("Hold ⌘ and drag the blob to put it anywhere on any edge.")
            }
            Section {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                Button("Check for Updates…", action: checkForUpdates)
            }
        }
        .formStyle(.grouped)
    }

    private static func describe(_ level: Cleanup, polishable: Bool, english: Bool, language: String) -> String {
        let model = !Polish.available ? " Needs Apple Intelligence, which is off or not ready on this Mac, so for now it's Light."
            : !polishable ? " Apple Intelligence doesn't speak \(language) yet, so for now it's Light." : ""
        switch level {
        case .light:
            return "Takes out um and uh, and stumbles like “the the”. Nothing else changes."
        case .medium:
            return "Also fixes punctuation and grammar with Apple Intelligence, a sentence at a time as you talk. Your words stay: if it drops one, Yap pastes its own version of that sentence." + model
        case .heavy:
            let missing = !Polish.available ? " Lists and grammar need Apple Intelligence, which is off or not ready on this Mac."
                : !polishable ? " Lists and grammar need Apple Intelligence, which doesn't speak \(language) yet." : ""
            return "Also drops what you take back, so “send it to John, no wait, Sarah” is “send it to Sarah”, and turns lists into bullet points."
                + (english ? "" : " Taking back is English only.") + missing
        }
    }

    /// Downloads a language you've just picked, so your first dictation in it doesn't wait for it.
    private func fetch(_ id: String) async {
        downloadFailed = false
        guard !(await Language.installed(id)) else { return }
        let transcriber = SpeechTranscriber(locale: Locale(identifier: id), transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        do {
            guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else { return }
            download = request.progress
            defer { download = nil }
            try await request.downloadAndInstall()
        } catch {
            if !Task.isCancelled { downloadFailed = true }
        }
    }
}

private struct WordsPane: View {
    @AppStorage("learnWords") private var learnWords = true
    @State private var learned = Words.learned()
    @State private var suggestions: [(word: String, count: Int)] = []
    @AppStorage("dismissedSuggestions") private var dismissed = ""
    @State private var correcting: String?
    @State private var correction = ""

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $learnWords) {
                    Text("Learn my words")
                    Text("Yap listens for names on your screen and from apps like rush, and fixes near misses, like “Reddis” to “Redis”; seen a few times, they're learned. Fix a word after Yap pastes it, or in History, and it'll get it right next time. Words you keep deleting, like “basically”, get dropped. Nothing it reads is saved.")
                }
                LabeledContent("Your words") {
                    Button("Edit…") { Words.ensureFile(); NSWorkspace.shared.open(Words.file) }
                }
            } footer: {
                Text("One word or name per line, “btw => by the way” to swap a phrase, or “drop: basically” to drop a filler.")
            }
            Section {
                if suggestions.isEmpty {
                    Text("Nothing to suggest yet.").foregroundStyle(.secondary)
                }
                ForEach(suggestions, id: \.word) { s in
                    LabeledContent {
                        HStack {
                            if correcting == s.word {
                                TextField("Should be", text: $correction, prompt: Text("What you said"))
                                    .frame(width: 160)
                                    .onSubmit {
                                        let fixed = correction.trimmingCharacters(in: .whitespaces)
                                        if !fixed.isEmpty { Words.addLearned("\(s.word.lowercased()) => \(fixed)") }
                                        correcting = nil; refresh()
                                    }
                                    .onExitCommand { correcting = nil }
                            }
                            Button("Should be…", systemImage: "pencil.circle") { correction = ""; correcting = s.word }
                            Button("Add", systemImage: "plus.circle") { Words.addLearned(s.word); refresh() }
                            Button("Not a word", systemImage: "xmark.circle") { dismissed += s.word.lowercased() + "\n"; refresh() }
                        }
                        .labelStyle(.iconOnly).buttonStyle(.borderless)
                    } label: {
                        Text(s.word)
                        Text("said \(s.count) times")
                    }
                }
            } header: {
                Text("Suggested")
            } footer: {
                Text("Words in your history that macOS's dictionary doesn't know. Add the right ones so Yap hears them; for a mishearing, like “Langy”, say what it should be.")
            }
            Section("Learned") {
                if learned.isEmpty {
                    Text("Nothing yet.").foregroundStyle(.secondary)
                }
                ForEach(learned, id: \.self) { line in
                    LabeledContent(line) {
                        Button("Forget", systemImage: "minus.circle") { Words.forgetLearned(line); refresh() }
                            .labelStyle(.iconOnly).buttonStyle(.borderless)
                    }
                }
                if !learned.isEmpty {
                    Button("Forget All", role: .destructive) { Words.forgetLearned(); refresh() }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        learned = Words.learned()
        let known = Words.known().union(dismissed.split(separator: "\n").map(String.init))
        suggestions = Learn.suggestions(from: Journal.entries().map(\.text), known: known)
    }
}

private struct PrivacyPane: View {
    let m: Dictation
    @AppStorage("keepHistory") private var keepHistory = true
    @AppStorage("historyRetentionDays") private var historyDays = 0.0
    @AppStorage("audioRetentionHours") private var audioHours = 0.0
    @State private var confirmDelete = false
    @State private var kept = (transcripts: 0, logBytes: 0, recordings: 0)

    var body: some View {
        Form {
            Section {
                LabeledContent("Transcripts", value: kept.transcripts == 0 ? "None"
                    : "\(kept.transcripts), \(ByteCountFormatter.string(fromByteCount: Int64(kept.logBytes), countStyle: .file))")
                LabeledContent("Recordings", value: audioHours < 0.5 ? (kept.recordings == 0 ? "None, off" : "\(kept.recordings), deleted soon")
                    : "\(kept.recordings), kept for \(Privacy.describe(hours: audioHours))")
            } header: {
                Text("Kept now")
            }
            Section {
                Toggle(isOn: $keepHistory) {
                    Text("Save what I say")
                    Text("Off, Yap still logs how long each dictation took, but none of your words.")
                }
                Picker("Keep history for", selection: $historyDays) {
                    Text("A day").tag(1.0)
                    Text("A week").tag(7.0)
                    Text("30 days").tag(30.0)
                    Text("A year").tag(365.0)
                    Text("Forever").tag(0.0)
                }
                .disabled(!keepHistory)
            } header: {
                Text("History")
            }
            Section {
                Picker("Keep recordings for", selection: $audioHours) {
                    Text("Never").tag(0.0)
                    Text("A day").tag(24.0)
                    Text("3 days").tag(72.0)
                    Text("A week").tag(168.0)
                }
            } header: {
                Text("Recordings")
            } footer: {
                Text("Handy for checking what Yap misheard. Turning this off deletes the ones you have.")
            }
            Section {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([Journal.logFile]) }
                Button("Delete All History…", role: .destructive) { confirmDelete = true }
            } footer: {
                Text("Everything stays on this Mac. Nothing you say is sent anywhere.")
            }
        }
        .formStyle(.grouped)
        .onAppear { kept = Journal.stats() }
        .onChange(of: historyDays) { UserDefaults.standard.set(true, forKey: Privacy.chosenKey); Journal.forget(); kept = Journal.stats() }
        .onChange(of: audioHours) { Journal.reap(); kept = Journal.stats() }
        .confirmationDialog("Delete all history?", isPresented: $confirmDelete) {
            Button("Delete All", role: .destructive) { Journal.deleteAll(); m.recent = []; kept = Journal.stats() }
        } message: {
            Text("Every transcript and recording Yap has kept. Your words and learned words stay.")
        }
    }
}

/// Opens the window from the menu at a pane; a menu bar app has to bring itself forward first.
struct SettingsButton: View {
    let title: String
    let pane: SettingsView.Pane
    @Environment(\.openWindow) private var openWindow
    @AppStorage("settingsPane") private var selected = SettingsView.Pane.general

    var body: some View {
        Button(title) { selected = pane; NSApp.activate(); openWindow(id: "settings") }
    }
}
