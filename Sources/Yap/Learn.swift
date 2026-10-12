import AppKit

/// Learns your words from the corrections you make after Yap pastes, the way Wispr Flow does.
/// It reads back only the text box Yap pasted into, for 30 s, and keeps nothing of it but the words it learns,
/// which go in ~/.config/yap/learned.txt (delete a line to forget one). Apps that don't expose their text
/// to Accessibility (most terminals, Electron apps) learn nothing.
enum Learn {
    enum Lesson: Equatable {
        case term(String)               // "langwatch" fixed to "LangWatch": help the recogniser spell it
        case swap(String, String, Int)  // "lang watch" to "LangWatch": replace it, once seen this many times
        case filler(String, Int)        // "basically" deleted: drop it when it's set off by commas, once seen this many times
    }

    static var enabled: Bool { UserDefaults.standard.object(forKey: "learnWords") as? Bool ?? true }

    /// What a correction teaches, comparing what Yap pasted with what's there now. Only one fix per dictation
    /// is learned, and nothing from a rewrite. `deliberate`: you edited it in History, so every fix counts,
    /// and sooner.
    static func lessons(pasted: String, edited: String, deliberate: Bool = false) -> [Lesson] {
        let a = words(pasted), b = words(edited)
        if deliberate { return hunks(a, b).flatMap { change(a, $0.old, $0.new, deliberate: true) } }
        var old = a[...], new = b[...]
        while let x = old.first, let y = new.first, x == y { old.removeFirst(); new.removeFirst() }
        while let x = old.last, let y = new.last, x == y { old.removeLast(); new.removeLast() }
        // shortcut: a single changed stretch; several fixes in one go teach nothing.
        guard Double(max(old.count, new.count)) <= 0.3 * Double(a.count) + 1 else { return [] }
        return change(a, old, new, deliberate: false)
    }

    private static func words(_ s: String) -> [String] {
        s.split(whereSeparator: \.isWhitespace).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }
    }

    /// One changed stretch: `old` (a slice of `all`, what was pasted) became `new`.
    private static func change(_ all: [String], _ old: ArraySlice<String>, _ new: ArraySlice<String>, deliberate: Bool) -> [Lesson] {
        if new.isEmpty {
            // Deleted words that aren't a repeat of their neighbour ("the the"): filler, if you keep doing it.
            let before = old.startIndex > all.startIndex ? all[old.startIndex - 1].lowercased() : nil
            let after = old.endIndex < all.endIndex ? all[old.endIndex].lowercased() : nil
            guard (1...3).contains(old.count), old.allSatisfy({ $0.contains(where: \.isLetter) }),
                  before != old.first?.lowercased(), after != old.last?.lowercased() else { return [] }
            return [.filler(old.joined(separator: " ").lowercased(), deliberate ? 2 : 3)]
        }
        guard (1...2).contains(old.count), (1...2).contains(new.count) else { return [] }
        let was = old.joined(separator: " "), now = new.joined(separator: " ")
        let squashed = was.replacingOccurrences(of: " ", with: "")
        if new.count == 1, squashed.lowercased() == now.lowercased(), squashed != now {
            // Same letters, new capitals or joined up: worth knowing if it's not an ordinary word.
            guard distinctive(now) else { return [] }
            return old.count == 1 ? [.term(now)] : [.term(now), .swap(was, now, deliberate ? 1 : 2)]
        }
        guard old.count == 1, new.count == 1, now.count >= 3,
              was.first?.lowercased() == now.first?.lowercased() || deliberate,
              distance(was.lowercased(), now.lowercased()) <= max(1, Int((deliberate ? 0.6 : 0.4) * Double(now.count))) else { return [] }
        // A misheard word: sure after two sightings for a name, three for an ordinary word.
        let needed = distinctive(now) ? 2 : 3
        return [.swap(was, now, deliberate ? needed - 1 : needed)]
    }

    /// The stretches that differ between two lists of words, by longest common run.
    static func hunks(_ a: [String], _ b: [String]) -> [(old: ArraySlice<String>, new: ArraySlice<String>)] {
        var lcs = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
            }
        }
        var out: [(old: ArraySlice<String>, new: ArraySlice<String>)] = []
        var i = 0, j = 0, oi = 0, nj = 0
        func flush() { if oi < i || nj < j { out.append((a[oi..<i], b[nj..<j])) } }
        while i < a.count || j < b.count {
            if i < a.count, j < b.count, a[i] == b[j] { flush(); i += 1; j += 1; oi = i; nj = j }
            else if j < b.count, i == a.count || lcs[i][j + 1] >= lcs[i + 1][j] { j += 1 }
            else { i += 1 }
        }
        flush()
        return out
    }

    /// Names and terms you keep saying that macOS's dictionary doesn't know, most said first: the ones the
    /// recogniser most needs telling about. Works on everything in History, so terminals count too.
    @MainActor
    static func suggestions(from texts: [String], known: Set<String>, atLeast: Int = 3) -> [(word: String, count: Int)] {
        var forms: [String: [String: Int]] = [:] // lowercased → how often each spelling was written
        for t in texts {
            for w in words(t) where w.count >= 3 && w.contains(where: \.isLetter) && !w.contains("'") && !w.contains("’") {
                forms[w.lowercased(), default: [:]][w, default: 0] += 1
            }
        }
        let checker = NSSpellChecker.shared
        // Your spelling: "colour" is a word in en_GB.
        let language = UserDefaults.standard.string(forKey: "locale") ?? Dictation.defaultLocale
        return forms.compactMap { key, spellings -> (word: String, count: Int)? in
            let count = spellings.values.reduce(0, +)
            guard count >= atLeast, !known.contains(key), let word = spellings.max(by: { $0.value < $1.value })?.key else { return nil }
            let unknown = checker.checkSpelling(of: word, startingAt: 0, language: language, wrap: false, inSpellDocumentWithTag: 0, wordCount: nil).location != NSNotFound
            return unknown ? (word, count) : nil
        }
        .sorted { ($0.count, $1.word) > ($1.count, $0.word) }
        .prefix(20).map { $0 }
    }

    /// Capitals inside, all capitals, or a digit: "LangWatch", "AWS", "k8s".
    static func distinctive(_ w: String) -> Bool {
        w.count >= 2 && (w.dropFirst().contains(where: \.isUppercase) || w.allSatisfy { $0.isUppercase || $0.isNumber } || w.contains(where: \.isNumber))
    }

    private static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }
        var row = Array(0...b.count)
        for i in 1...a.count {
            var prev = row[0]; row[0] = i
            for j in 1...b.count {
                let cur = row[j]
                row[j] = min(row[j] + 1, row[j - 1] + 1, prev + (a[i - 1] == b[j - 1] ? 0 : 1))
                prev = cur
            }
        }
        return row[b.count]
    }

    /// The text between two anchors, or nil once either has gone (the message was sent, or the box cleared).
    static func locate(before: String, after: String, in text: String) -> String? {
        let start = before.isEmpty ? text.startIndex : text.range(of: before)?.upperBound
        guard let start else { return nil }
        let end = after.isEmpty ? text.endIndex : text.range(of: after, range: start..<text.endIndex)?.lowerBound
        guard let end else { return nil }
        let span = String(text[start..<end])
        return span.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : span
    }

    // MARK: Saving

    /// Returns the lines it added to learned.txt.
    @discardableResult
    static func record(_ lessons: [Lesson]) -> [String] {
        var learned: [String] = []
        func learn(_ line: String) { if Words.addLearned(line) { learned.append(line) } }
        var pending = UserDefaults.standard.dictionary(forKey: "learnPending") as? [String: Int] ?? [:]
        for lesson in lessons {
            switch lesson {
            case .term(let t):
                learn(t)
            case .swap(let was, let now, let needed):
                let key = "\(was.lowercased()) => \(now)"
                pending[key, default: 0] += 1
                if pending[key]! >= needed { learn(key); pending[key] = nil }
            case .filler(let phrase, let needed):
                let key = "drop: \(phrase)"
                pending[key, default: 0] += 1
                if pending[key]! >= needed { learn(key); pending[key] = nil }
            }
        }
        UserDefaults.standard.set(pending, forKey: "learnPending")
        return learned
    }

    // MARK: Watching the text box

    private static var watch: Timer?

    /// Call just after pasting `pasted`. Reads the focused text box back every 2 s for 30 s.
    static func watch(pasted: String, field given: AXUIElement? = nil, every: TimeInterval = 2) {
        watch?.invalidate(); watch = nil
        guard enabled, AXIsProcessTrusted() else { return }
        // Give the paste a moment to land.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let field = given ?? focusedField(), let text = value(field), let caret = caret(field) else { return }
            let ns = text as NSString, length = (pasted as NSString).length
            guard caret >= length, caret <= ns.length, ns.substring(with: NSRange(location: caret - length, length: length)) == pasted else { return }
            let before = ns.substring(with: NSRange(location: max(0, caret - length - 30), length: min(30, caret - length)))
            let after = ns.substring(with: NSRange(location: caret, length: min(30, ns.length - caret)))
            var last = pasted, ticks = 0
            watch = Timer.scheduledTimer(withTimeInterval: every, repeats: true) { timer in
                ticks += 1
                if let now = value(field), let span = locate(before: before, after: after, in: now) { last = span }
                else { ticks = 15 } // gone: judge what we last saw
                guard ticks >= 15 else { return }
                timer.invalidate()
                record(lessons(pasted: pasted, edited: last))
            }
        }
    }

    private static func attribute(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
    }

    private static func focusedField() -> AXUIElement? {
        guard let f = attribute(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute) else { return nil }
        let field = f as! AXUIElement
        // Never read password boxes.
        guard attribute(field, kAXSubroleAttribute) as? String != kAXSecureTextFieldSubrole else { return nil }
        return field
    }

    private static func value(_ e: AXUIElement) -> String? {
        guard let s = attribute(e, kAXValueAttribute) as? String, s.utf16.count < 100_000 else { return nil }
        return s
    }

    private static func caret(_ e: AXUIElement) -> Int? {
        guard let v = attribute(e, kAXSelectedTextRangeAttribute) else { return nil }
        var range = CFRange()
        return AXValueGetValue(v as! AXValue, .cfRange, &range) ? range.location : nil
    }

    static func selfTest() {
        precondition(lessons(pasted: "ping lang watch now", edited: "ping LangWatch now") == [.term("LangWatch"), .swap("lang watch", "LangWatch", 2)])
        precondition(lessons(pasted: "the langwatch app ", edited: "the LangWatch app") == [.term("LangWatch")])
        precondition(lessons(pasted: "deploy to heaven today", edited: "deploy to haven today") == [.swap("heaven", "haven", 3)])
        precondition(lessons(pasted: "great idea", edited: "awesome plan") == [])            // a rewrite
        precondition(lessons(pasted: "the the cat", edited: "the cat") == [])                 // a repeat, not a filler
        precondition(lessons(pasted: "so basically we ship", edited: "so we ship") == [.filler("basically", 3)])
        precondition(lessons(pasted: "ping lang watch and deploy to heaven today, basically, ok", edited: "ping LangWatch and deploy to haven today ok", deliberate: true)
                     == [.term("LangWatch"), .swap("lang watch", "LangWatch", 1), .swap("heaven", "haven", 2), .filler("basically", 2)])
        precondition(lessons(pasted: "great idea", edited: "awesome plan", deliberate: true) == [])
        precondition(lessons(pasted: "Send it now", edited: "send it now") == [])             // ordinary capitals
        precondition(lessons(pasted: "I said hello there", edited: "I said goodbye there") == []) // not a mishearing
        precondition(locate(before: "Hi. ", after: " Bye", in: "Hi. fixed text Bye") == "fixed text")
        precondition(locate(before: "Hi. ", after: "", in: "Hi. tail") == "tail")
        precondition(locate(before: "Hi. ", after: "", in: "") == nil)
        print("learn self-test passed")
    }
}
