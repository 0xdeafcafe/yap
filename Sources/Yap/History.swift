import AVFoundation
import SwiftUI

/// Every dictation you've pasted, newest first, by day. Search, copy, and play the recording if you keep them.
struct HistoryView: View {
    @Binding var entries: [Journal.Entry]
    /// The window's search field, which is in the toolbar of every pane.
    let search: String
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
                            ForEach(group.entries) { Row(entry: $0, play: play) { entries = Journal.entries() } }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 360)
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
    let edited: () -> Void
    @State private var hovering = false
    @State private var copied = false
    @State private var editing = false
    @State private var draft = ""
    @State private var learned: [String] = []
    @FocusState private var focused: Bool

    private var app: AppInfo { AppInfo.of(entry.app) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Always the same slot, so rows from an app that's gone still line up with the rest.
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon).resizable().interpolation(.high)
                } else {
                    Image(systemName: "app.dashed").font(.title3).foregroundStyle(.tertiary)
                }
            }
            .frame(width: 20, height: 20).padding(.top, 1)
            .help(app.name)
            VStack(alignment: .leading, spacing: 4) {
                if editing {
                    TextField("Transcript", text: $draft, axis: .vertical)
                        .textFieldStyle(.plain).focused($focused)
                        .onSubmit(save).onExitCommand { editing = false }
                    Text("Return to save, Esc to cancel. Yap learns from what you fix.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Said.marked(entry.text, fixed: entry.fixed.map(\.now), style: .primary, mark: Color(nsColor: .systemOrange)).textSelection(.enabled)
                }
                if !entry.fixed.isEmpty, !editing {
                    Text("Heard " + entry.fixed.map { "“\($0.was)”, wrote \($0.now)" }.joined(separator: "; ") + ", from your screen")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !learned.isEmpty {
                    Label("Learned " + learned.joined(separator: ", "), systemImage: "sparkles")
                        .font(.caption).foregroundStyle(.tint)
                }
                Text("\(entry.at.formatted(date: .omitted, time: .shortened)) · \(app.name) · \(entry.seconds, format: .number.precision(.fractionLength(1))) s")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                if let audio = entry.audio {
                    Button("Play", systemImage: "play.fill") { play(audio) }
                }
                Button("Fix", systemImage: "pencil") { startEditing() }
                Button(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.text, forType: .string)
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                }
            }
            .labelStyle(.iconOnly).buttonStyle(.borderless)
            .opacity((hovering || copied) && !editing ? 1 : 0)
        }
        .padding(.vertical, 4)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.text, forType: .string)
            }
            Button("Fix…") { startEditing() }
            if let audio = entry.audio { Button("Play recording") { play(audio) } }
        }
    }

    private func startEditing() {
        draft = entry.text; editing = true; focused = true
    }

    /// Keeps your version and learns from the difference: every fix counts, since you meant each one.
    private func save() {
        editing = false
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != entry.text else { return }
        Journal.edit(id: entry.id, text: text)
        if Learn.enabled { learned = Learn.record(Learn.lessons(pasted: entry.text, edited: text, deliberate: true)) }
        edited()
        if !learned.isEmpty { Task { try? await Task.sleep(for: .seconds(5)); learned = [] } }
    }
}

/// An app's name and icon, looked up once per app instead of on every redraw of every row.
@MainActor struct AppInfo {
    let name: String
    let icon: NSImage?
    private static var cache: [String: AppInfo] = [:]

    static func of(_ bundleID: String) -> AppInfo {
        if let hit = cache[bundleID] { return hit }
        var info = AppInfo(name: bundleID, icon: nil)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            info = AppInfo(name: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""),
                           icon: NSWorkspace.shared.icon(forFile: url.path))
        }
        cache[bundleID] = info
        return info
    }
}
