import SwiftUI

/// One window for everything you can change, and your history: a sidebar on the left, the way
/// System Settings does it, so macOS draws it in Liquid Glass.
struct SettingsView: View {
    let m: Dictation
    let checkForUpdates: () -> Void
    @AppStorage("settingsPane") private var pane = Pane.general

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
            switch pane {
            case .general: GeneralPane(checkForUpdates: checkForUpdates).navigationTitle("General")
            case .words: WordsPane().navigationTitle("Words")
            case .privacy: PrivacyPane(m: m).navigationTitle("Privacy")
            case .history: HistoryView(m: m).navigationTitle("History")
            }
        }
        .frame(minWidth: 680, minHeight: 460)
    }
}

private struct GeneralPane: View {
    let checkForUpdates: () -> Void
    @AppStorage("locale") private var locale = Dictation.defaultLocale
    @AppStorage("edge") private var edge = Dictation.Edge.right.rawValue
    @AppStorage("appIcon") private var appIcon = AppIcon.cream.rawValue
    @AppStorage("formatting") private var formatting = false
    @AppStorage("polish") private var polish = false

    var body: some View {
        Form {
            Section {
                Picker("Spelling", selection: $locale) {
                    Text("British").tag("en_GB")
                    Text("American").tag("en_US")
                }
                Toggle(isOn: $formatting) {
                    Text("Formatting")
                    Text("Say “new line”, “bullet”, or “code npm test end code”.")
                }
                Toggle(isOn: $polish) {
                    Text("Tidy grammar with Apple Intelligence")
                    Text(Polish.available
                         ? "Experimental. Fixes punctuation and grammar on your Mac, adding about a second. If it drops any of your words, Yap pastes its own version instead."
                         : "Needs Apple Intelligence, which is off or not ready on this Mac.")
                }
                .disabled(!Polish.available)
            }
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
                    Text("Fix a word after Yap pastes it, or fix it in History, and it'll get it right next time. Words you keep deleting, like “basically”, get dropped. After a paste Yap reads back only the box it pasted into, for 30 seconds; terminals don't share their text, so fix those in History.")
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

    var body: some View {
        Form {
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
        .onChange(of: historyDays) { Journal.forget() }
        .onChange(of: audioHours) { Journal.reap() }
        .confirmationDialog("Delete all history?", isPresented: $confirmDelete) {
            Button("Delete All", role: .destructive) { Journal.deleteAll(); m.recent = [] }
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
