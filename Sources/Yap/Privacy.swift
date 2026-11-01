import AppKit

/// What Yap keeps, said once, and kept to a sensible default.
enum Privacy {
    static let retentionKey = "historyRetentionDays"
    static let noticeKey = "privacyNoticeShown"
    static let openSettings = Notification.Name("YapOpenPrivacySettings")

    /// How long to keep transcripts when nobody's chosen yet: 30 days for a new install, forever for one that
    /// already has a log, so nothing older is deleted by surprise. nil once a choice is recorded.
    static func retentionDefault(stored: Any?, logExists: Bool) -> Double? {
        stored == nil ? (logExists ? 0 : 30) : nil
    }

    /// On the first run of this version, writes the retention down so it's an explicit choice from then on.
    static func settleRetention(_ defaults: UserDefaults = .standard, logExists: Bool = FileManager.default.fileExists(atPath: Journal.logFile.path)) {
        if let days = retentionDefault(stored: defaults.object(forKey: retentionKey), logExists: logExists) {
            defaults.set(days, forKey: retentionKey)
        }
    }

    static func describe(days: Double) -> String {
        switch days {
        case ..<0.5: "forever"
        case 1: "a day"
        case 7: "a week"
        case 365: "a year"
        default: "\(Int(days)) days"
        }
    }

    static func describe(hours: Double) -> String {
        switch hours {
        case ..<0.5: "off"
        case 24: "a day"
        case 168: "a week"
        case ..<24: "\(Int(hours)) hours"
        default: "\(Int((hours / 24).rounded())) days"
        }
    }

    /// The notice's words, for the settings as they are now.
    static func notice(_ defaults: UserDefaults = .standard) -> String {
        let keepText = defaults.object(forKey: "keepHistory") as? Bool ?? true
        let days = defaults.object(forKey: retentionKey) as? Double ?? 0
        let hours = defaults.object(forKey: "audioRetentionHours") as? Double ?? 0
        let transcripts = !keepText ? "Yap isn't saving what you say, only how long each dictation took."
            : days < 0.5 ? "Transcripts of what you say are kept forever, so you can find them in History."
            : "Transcripts of what you say are kept for \(describe(days: days)), so you can find them in History."
        let recordings = hours < 0.5 ? "Recordings are off." : "Recordings are kept for \(describe(hours: hours))."
        return "\(transcripts) \(recordings) They're in ~/Library/Logs/Yap and ~/Library/Application Support/Yap. Nothing leaves your Mac.\n\nTo spell names right, Yap also looks at the words in the window you're talking into. It never saves what it reads."
    }

    /// Once per install of this version: says what's kept, with a way to change it.
    @MainActor
    static func showNoticeOnce(_ defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: noticeKey) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            defaults.set(true, forKey: noticeKey)
            let alert = NSAlert()
            alert.messageText = "What Yap keeps"
            alert.informativeText = notice(defaults)
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Privacy Settings…")
            NSApp.activate()
            if alert.runModal() == .alertSecondButtonReturn {
                defaults.set("privacy", forKey: "settingsPane")
                NotificationCenter.default.post(name: openSettings, object: nil)
            }
        }
    }

    static func selfTest() {
        precondition(retentionDefault(stored: nil, logExists: false) == 30)   // a new install
        precondition(retentionDefault(stored: nil, logExists: true) == 0)     // an existing one keeps everything
        precondition(retentionDefault(stored: 7.0, logExists: true) == nil)   // a choice is never changed
        precondition(retentionDefault(stored: 0.0, logExists: false) == nil)
        let suite = "red.forbes.yap.selftest.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        defer { d.removePersistentDomain(forName: suite) }
        settleRetention(d, logExists: true)
        precondition(d.double(forKey: retentionKey) == 0 && d.object(forKey: retentionKey) != nil)
        settleRetention(d, logExists: false)                                  // the next run leaves it be
        precondition(d.double(forKey: retentionKey) == 0)
        precondition(notice(d).contains("kept forever") && notice(d).contains("Recordings are off"))
        d.removeObject(forKey: retentionKey)
        settleRetention(d, logExists: false)
        d.set(72.0, forKey: "audioRetentionHours")
        precondition(notice(d).contains("kept for 30 days") && notice(d).contains("kept for 3 days"), notice(d))
        print("privacy self-test passed")
    }
}

extension Journal {
    /// What's kept right now, for Settings › Privacy.
    static func stats() -> (transcripts: Int, logBytes: Int, recordings: Int) {
        let fm = FileManager.default
        let bytes = ((try? fm.attributesOfItem(atPath: logFile.path))?[.size] as? Int) ?? 0
        let recordings = ((try? fm.contentsOfDirectory(atPath: audioDir.path)) ?? []).filter { $0.hasSuffix(".wav") }.count
        return (entries().count, bytes, recordings)
    }
}
