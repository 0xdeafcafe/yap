import AVFoundation
import SwiftUI

/// Every dictation you've pasted, newest first, by day. Search, copy, and play the recording if you keep them.
struct HistoryView: View {
    let m: Dictation
    @State private var entries = Journal.entries()
    @State private var search = ""
    @State private var player: AVAudioPlayer?

    private var shown: [Journal.Entry] {
        search.isEmpty ? entries : entries.filter { $0.text.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView("Nothing yet", systemImage: "text.bubble",
                                       description: Text("Hold fn and talk. What Yap pastes shows up here."))
            } else if shown.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                List {
                    ForEach(days, id: \.day) { group in
                        Section(title(group.day)) {
                            ForEach(group.entries) { Row(entry: $0, play: play) }
                        }
                    }
                }
            }
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Search what you said")
        .navigationSubtitle(entries.isEmpty ? "" : "\(entries.count) dictations")
        .frame(minWidth: 460, minHeight: 360)
        .onChange(of: m.recent) { entries = Journal.entries() }
    }

    private var days: [(day: Date, entries: [Journal.Entry])] {
        let cal = Calendar.current
        var out: [(day: Date, entries: [Journal.Entry])] = []
        for e in shown {
            let day = cal.startOfDay(for: e.at)
            if out.last?.day == day { out[out.count - 1].entries.append(e) } else { out.append((day, [e])) }
        }
        return out
    }

    private func title(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private func play(_ url: URL) {
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}

private struct Row: View {
    let entry: Journal.Entry
    let play: (URL) -> Void
    @State private var hovering = false
    @State private var copied = false

    private var app: (name: String, icon: NSImage?) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.app) else { return (entry.app, nil) }
        return (FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""), NSWorkspace.shared.icon(forFile: url.path))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let icon = app.icon {
                Image(nsImage: icon).resizable().frame(width: 20, height: 20).padding(.top, 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text).textSelection(.enabled)
                Text("\(entry.at.formatted(date: .omitted, time: .shortened)) · \(app.name) · \(entry.seconds, format: .number.precision(.fractionLength(1))) s")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                if let audio = entry.audio {
                    Button("Play", systemImage: "play.fill") { play(audio) }
                }
                Button(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.text, forType: .string)
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                }
            }
            .labelStyle(.iconOnly).buttonStyle(.borderless)
            .opacity(hovering || copied ? 1 : 0)
        }
        .padding(.vertical, 4)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.text, forType: .string)
            }
            if let audio = entry.audio { Button("Play recording") { play(audio) } }
        }
    }
}

/// Opens the History window from the menu; a menu bar app has to bring itself forward first.
struct HistoryButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("History…") { NSApp.activate(); openWindow(id: "history") }.keyboardShortcut("h")
    }
}
