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

struct GeneralPane: View {
    let checkForUpdates: () -> Void
    @AppStorage("locale") private var locale = Dictation.defaultLocale
    @AppStorage("edge") private var edge = Dictation.Edge.right.rawValue
    @AppStorage("showAt") private var showAt = Dictation.ShowAt.cursor.rawValue
    @AppStorage("appIcon") private var appIcon = AppIcon.cream.rawValue
    @AppStorage("formatting") private var formatting = false
    @AppStorage("cleanup") private var cleanup = Cleanup.current.rawValue
    /// Every language Apple's recogniser can dictate; until it answers, just the one you have.
    @State private var languages: [String] = []
    @State private var download: Progress?
    @State private var downloadFailed = false
    @State private var modelMissing = Polish.unavailable

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
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Cleanup", selection: $cleanup) {
                        ForEach(Cleanup.allCases, id: \.rawValue) { Text($0.rawValue.capitalized).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    CleanupExample(level: level)
                    Text(Self.describe(level, polishable: polishable, english: english, language: Language.name(locale)))
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                // Medium and Heavy need Apple's model: say why it can't run yet, and where to turn it on.
                if level != .light, let missing = modelMissing {
                    LabeledContent {
                        if missing.canTurnOn { Button("Open System Settings") { Polish.openAppleIntelligenceSettings() } }
                    } label: {
                        Label("Needs Apple Intelligence", systemImage: "exclamationmark.triangle")
                        Text(missing.reason)
                    }
                }
            }
            .task { languages = await Language.dictatable() }
            .task {
                // It can be turned on, or finish downloading, while Settings is open.
                while !Task.isCancelled {
                    modelMissing = Polish.unavailable
                    try? await Task.sleep(for: .seconds(3))
                }
            }
            .task(id: locale) { await fetch(locale) }
            Section {
                Picker(selection: $showAt) {
                    Text("Next to the cursor").tag(Dictation.ShowAt.cursor.rawValue)
                    Text("At the blob").tag(Dictation.ShowAt.blob.rawValue)
                } label: {
                    Text("Show while talking")
                    Text("Where an app doesn't say where its cursor is, like most terminals, Yap shows at the blob.")
                }
                LabeledContent {
                    EdgePicker(edge: $edge)
                } label: {
                    Text("Blob")
                    Text("Which edge of the screen it sits on. Hold ⌘ and drag it to move it along one.")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("App icon")
                    IconPicker(selection: $appIcon)
                }
            }
            Section {
                LabeledContent {
                    Button("Check for Updates…", action: checkForUpdates)
                } label: {
                    Text("Yap \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                }
            }
        }
        .formStyle(.grouped)
    }

    static func describe(_ level: Cleanup, polishable: Bool, english: Bool, language: String) -> String {
        // Without Apple Intelligence it's Light; the note below says why. A language it doesn't speak is said here.
        let model = Polish.available && !polishable ? " Apple Intelligence doesn't speak \(language) yet, so for now it's Light." : ""
        switch level {
        case .light:
            return "Takes out um and uh, and stumbles like “the the”. Nothing else changes."
        case .medium:
            return "Apple Intelligence fixes punctuation and grammar as you talk, on this Mac. If it ever drops a word you said, Yap keeps yours." + model
        case .heavy:
            return "Also drops what you take back and turns lists into bullet points." + (english ? "" : " Taking back is English only.") + model
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
    @State private var fromApps: [String] = []

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $learnWords) {
                    Text("Learn my words")
                    Text("Hears “reddis” with Redis on screen and writes Redis. Learns from what you fix and drops fillers you keep deleting. Nothing it reads is saved.")
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
                            if correcting != s.word {
                                Button("It's actually…") { correction = ""; correcting = s.word }
                                Button("Ignore") { dismissed += s.word.lowercased() + "\n"; refresh() }
                                Button("Add") { Words.addLearned(s.word); refresh() }.buttonStyle(.borderedProminent)
                            }
                        }
                        .controlSize(.small)
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
            if !fromApps.isEmpty {
                Section {
                    Text(fromApps.prefix(60).joined(separator: "  ·  "))
                        .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                } header: {
                    Text("Listening for now")
                } footer: {
                    Text("Sent by apps like rush, for what's on their screen. Forgotten when they close.")
                }
            }
            Section("Learned") {
                if learned.isEmpty {
                    Text("Nothing yet. Fix a name after Yap pastes it, or in History, and it'll show up here.").foregroundStyle(.secondary)
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
        fromApps = Live.shared.allWords
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
                    : "\(kept.transcripts) \(kept.transcripts == 1 ? "transcript" : "transcripts") · \(ByteCountFormatter.string(fromByteCount: Int64(kept.logBytes), countStyle: .file))")
                LabeledContent("Recordings", value: audioHours < 0.5 ? (kept.recordings == 0 ? "None, off" : "\(kept.recordings), deleted soon")
                    : "\(kept.recordings), kept for \(Privacy.describe(hours: audioHours))")
            } header: {
                Text("Kept now")
            }
            Section {
                Toggle(isOn: $keepHistory) {
                    Text("Save what I say")
                    Text(keepHistory ? "Your transcripts are kept here, so you can search, copy and fix them."
                                     : "Only how long each dictation took is logged. None of your words.")
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
                    .foregroundStyle(.red)
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

/// What each cleanup level does to the same thing said, so you pick by seeing it. Light is Yap's real rules;
/// the other two are what Apple's model typically makes of it.
private struct CleanupExample: View {
    let level: Cleanup
    static let said = "um send the the report to john no wait sarah"

    private var pasted: String {
        switch level {
        case .light: Tidy.clean(Self.said)
        case .medium: "Send the report to John, no wait, Sarah."
        case .heavy: "Send the report to Sarah."
        }
    }

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow {
                Text("You say").foregroundStyle(.secondary)
                Text(Self.said).foregroundStyle(.secondary)
            }
            GridRow {
                Text("Yap pastes").foregroundStyle(.secondary)
                Text(pasted).contentTransition(.opacity)
            }
        }
        .font(.callout)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
        .animation(.smooth(duration: 0.2), value: level)
    }
}

/// A little screen with the blob on the edge you pick; click an edge to move it there.
private struct EdgePicker: View {
    @Binding var edge: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.6))
            RoundedRectangle(cornerRadius: 6).strokeBorder(.tertiary, lineWidth: 1)
            ForEach(Dictation.Edge.allCases, id: \.self) { e in
                let on = edge == e.rawValue
                Button { edge = e.rawValue } label: {
                    Capsule().fill(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        .frame(width: e == .bottom ? 22 : 5, height: e == .bottom ? 5 : 22)
                        .padding(8)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: e.frameAlignment)
                .accessibilityLabel("\(e.rawValue.capitalized) edge")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .frame(width: 96, height: 60)
        .animation(.smooth(duration: 0.2), value: edge)
    }
}

/// The app icons, as pictures.
private struct IconPicker: View {
    @Binding var selection: String

    var body: some View {
        // One row of all of them: a lone icon wrapped onto a second row looks like an afterthought.
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 40, maximum: 64), spacing: 4), count: AppIcon.allCases.count), spacing: 4) {
            ForEach(AppIcon.allCases, id: \.rawValue) { icon in
                let on = selection == icon.rawValue
                Button { selection = icon.rawValue } label: {
                    Group {
                        if let image = icon.preview { Image(nsImage: image).resizable().interpolation(.high) }
                        else { Color.clear }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 48)
                    .padding(3)
                    .background {
                        RoundedRectangle(cornerRadius: 14).strokeBorder(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2.5)
                    }
                }
                .buttonStyle(.plain)
                .help(icon.title)
                .accessibilityLabel(icon.title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
