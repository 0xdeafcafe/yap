import Foundation

/// A record of every dictation, for working out how Yap performs.
/// - Log: ~/Library/Logs/Yap/dictations.jsonl, one JSON object per dictation (timings, text, outcome).
/// - Audio: off unless you opt in with `defaults write red.forbes.yap audioRetentionHours -float 72`.
///   Then one WAV per dictation goes in ~/Library/Application Support/Yap/audio and is deleted once
///   older than that many hours. Reaped at launch, after every dictation and every hour; turning it
///   off again deletes whatever is left.
enum Journal {
    private static let home = FileManager.default.homeDirectoryForCurrentUser
    static let logFile = home.appending(path: "Library/Logs/Yap/dictations.jsonl")
    static let audioDir = home.appending(path: "Library/Application Support/Yap/audio")

    static var retention: TimeInterval {
        max(0, UserDefaults.standard.object(forKey: "audioRetentionHours") as? Double ?? 0) * 3600
    }

    /// Where to record this dictation, or nil when audio isn't being kept.
    static func audioURL(for id: String) -> URL? {
        guard retention > 0, makePrivateDir(audioDir) else { return nil }
        return audioDir.appending(path: "\(id).wav")
    }

    static func write(_ entry: [String: Any]) {
        guard makePrivateDir(logFile.deletingLastPathComponent()),
              var line = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]) else { return }
        line.append(0x0A)
        let fm = FileManager.default
        if !fm.fileExists(atPath: logFile.path) {
            fm.createFile(atPath: logFile.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        guard let h = try? FileHandle(forWritingTo: logFile) else { return }
        defer { try? h.close() }
        _ = try? h.seekToEnd()
        try? h.write(contentsOf: line)
    }

    /// The text of the last `n` pasted dictations, newest first.
    static func recentTexts(_ n: Int) -> [String] {
        guard let log = try? String(contentsOf: logFile, encoding: .utf8) else { return [] }
        return log.split(separator: "\n").reversed().lazy
            .compactMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] }
            .filter { $0["outcome"] as? String == "pasted" }
            .compactMap { $0["text"] as? String }
            .prefix(n).map { $0 }
    }

    /// Deletes recordings older than `age`. Returns how many went.
    @discardableResult
    static func reap(dir: URL = audioDir, olderThan age: TimeInterval = retention, now: Date = Date()) -> Int {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return 0 }
        var removed = 0
        for f in files {
            let modified = (try? f.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if now.timeIntervalSince(modified) >= age, (try? fm.removeItem(at: f)) != nil { removed += 1 }
        }
        return removed
    }

    /// Recordings and transcripts are private: owner-only folders.
    private static func makePrivateDir(_ dir: URL) -> Bool {
        (try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])) != nil
    }

    static func selfTest() {
        let dir = FileManager.default.temporaryDirectory.appending(path: "yap-reap-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for (name, hoursOld) in [("old.wav", 80.0), ("new.wav", 1.0)] {
            let f = dir.appending(path: name)
            FileManager.default.createFile(atPath: f.path, contents: Data([1]))
            try! FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-hoursOld * 3600)], ofItemAtPath: f.path)
        }
        precondition(reap(dir: dir, olderThan: 72 * 3600) == 1)
        precondition((try! FileManager.default.contentsOfDirectory(atPath: dir.path)) == ["new.wav"])
        precondition(reap(dir: dir, olderThan: 0) == 1) // retention 0 clears everything
        print("reaper self-test passed")
    }
}
