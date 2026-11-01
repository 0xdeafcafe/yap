import AppKit

/// What Yap keeps, said once, and kept to a sensible default.
enum Privacy {
    static let retentionKey = "historyRetentionDays"
    /// The notice that comes with the 30-day default; until it's answered nothing is trimmed from the log.
    static let noticeKey = "privacyNotice2Shown"
    /// Set once you pick how long history's kept yourself, so the default never overrides you.
    static let chosenKey = "historyRetentionChosen"
    static let openSettings = Notification.Name("YapOpenPrivacySettings")

    /// How long to keep transcripts unless you've chosen: 30 days, for every install. nil when there's
    /// nothing to change. (0.3 wrote "forever" for installs that had a log; that wasn't your choice, so it goes too.)
    static func retentionDefault(stored: Any?, chosen: Bool) -> Double? {
        chosen || (stored as? Double) == 30 ? nil : 30
    }

    /// At launch, before anything reads or trims the log. Nothing older is deleted until the notice is answered.
    static func settleRetention(_ defaults: UserDefaults = .standard) {
        if let days = retentionDefault(stored: defaults.object(forKey: retentionKey), chosen: defaults.bool(forKey: chosenKey)) {
            defaults.set(days, forKey: retentionKey)
        }
    }

    /// Whether the log may be trimmed yet: only once you've seen what the default would delete.
    static var trimAllowed: Bool { UserDefaults.standard.bool(forKey: noticeKey) }

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
        let older = days < 0.5 || !keepText ? 0 : Journal.count(olderThanDays: days)
        let going = older == 0 ? "" : " \(older) of your transcripts are older than that and will be deleted, unless you keep them forever."
        return "\(transcripts)\(going) \(recordings) They're in ~/Library/Logs/Yap and ~/Library/Application Support/Yap. Nothing leaves your Mac.\n\nTo spell names right, Yap also looks at the words in the window you're talking into. It never saves what it reads."
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
            alert.addButton(withTitle: "Keep Forever")
            alert.addButton(withTitle: "Privacy Settings…")
            NSApp.activate()
            switch alert.runModal() {
            case .alertSecondButtonReturn:
                defaults.set(0.0, forKey: retentionKey); defaults.set(true, forKey: chosenKey)
            case .alertThirdButtonReturn:
                defaults.set("privacy", forKey: "settingsPane")
                NotificationCenter.default.post(name: openSettings, object: nil)
            default:
                Journal.forget()
            }
        }
    }

    static func selfTest() {
        precondition(retentionDefault(stored: nil, chosen: false) == 30)     // a new install
        precondition(retentionDefault(stored: 0.0, chosen: false) == 30)     // 0.3's "forever" wasn't yours
        precondition(retentionDefault(stored: 30.0, chosen: false) == nil)   // already there
        precondition(retentionDefault(stored: 0.0, chosen: true) == nil)     // your choice is never changed
        precondition(retentionDefault(stored: 7.0, chosen: true) == nil)
        let suite = "red.forbes.yap.selftest.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        defer { d.removePersistentDomain(forName: suite) }
        d.set(0.0, forKey: retentionKey)
        settleRetention(d)
        precondition(d.double(forKey: retentionKey) == 30)
        d.set(0.0, forKey: retentionKey); d.set(true, forKey: chosenKey)
        settleRetention(d)                                                    // chosen: left be
        precondition(d.double(forKey: retentionKey) == 0)
        precondition(notice(d).contains("kept forever") && notice(d).contains("Recordings are off"))
        d.removeObject(forKey: retentionKey); d.removeObject(forKey: chosenKey)
        settleRetention(d)
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
