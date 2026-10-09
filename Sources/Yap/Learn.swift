import AppKit

/// Learns your words from the corrections you make after Yap pastes, the way Wispr Flow does.
/// It reads back only the text box Yap pasted into, for 30 s, and keeps nothing of it but the words it learns,
/// which go in ~/.config/yap/learned.txt (delete a line to forget one). Apps that don't expose their text
/// to Accessibility (most terminals, Electron apps) learn nothing.
enum Learn {
    enum Lesson: Equatable {
        case term(String)               // "langwatch" fixed to "LangWatch": help the recogniser spell it
        case swap(String, String, Int)  // "lang watch" to "LangWatch": replace it, once seen this many times
    }

    static var enabled: Bool { UserDefaults.standard.object(forKey: "learnWords") as? Bool ?? true }

    /// What a correction teaches, comparing what Yap pasted with what's there now. Only one fix per dictation
    /// is learned, and nothing from a rewrite.
    static func lessons(pasted: String, edited: String) -> [Lesson] {
        func words(_ s: String) -> [String] {
            s.split(whereSeparator: \.isWhitespace).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }
        }
        var old = words(pasted)[...], new = words(edited)[...]
        while let a = old.first, let b = new.first, a == b { old.removeFirst(); new.removeFirst() }
        while let a = old.last, let b = new.last, a == b { old.removeLast(); new.removeLast() }
        // shortcut: a single changed stretch, one or two words each side; several fixes in one go teach nothing.
        guard (1...2).contains(old.count), (1...2).contains(new.count),
              Double(max(old.count, new.count)) <= 0.3 * Double(words(pasted).count) + 1 else { return [] }
        let was = old.joined(separator: " "), now = new.joined(separator: " ")
        let squashed = was.replacingOccurrences(of: " ", with: "")
        if new.count == 1, squashed.lowercased() == now.lowercased(), squashed != now {
            // Same letters, new capitals or joined up: worth knowing if it's not an ordinary word.
            guard distinctive(now) else { return [] }
            return old.count == 1 ? [.term(now)] : [.term(now), .swap(was, now, 2)]
        }
        guard old.count == 1, new.count == 1, now.count >= 3,
              was.first?.lowercased() == now.first?.lowercased(),
              distance(was.lowercased(), now.lowercased()) <= max(1, Int(0.4 * Double(now.count))) else { return [] }
        // A misheard word: sure after two sightings for a name, three for an ordinary word.
        return [.swap(was, now, distinctive(now) ? 2 : 3)]
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

    static func record(_ lessons: [Lesson]) {
        var pending = UserDefaults.standard.dictionary(forKey: "learnPending") as? [String: Int] ?? [:]
        for lesson in lessons {
            switch lesson {
            case .term(let t):
                Words.addLearned(t)
            case .swap(let was, let now, let needed):
                let key = "\(was.lowercased()) => \(now)"
                pending[key, default: 0] += 1
                if pending[key]! >= needed { Words.addLearned("\(was.lowercased()) => \(now)"); pending[key] = nil }
            }
        }
        UserDefaults.standard.set(pending, forKey: "learnPending")
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
        precondition(lessons(pasted: "the the cat", edited: "the cat") == [])                 // only a deletion
        precondition(lessons(pasted: "Send it now", edited: "send it now") == [])             // ordinary capitals
        precondition(lessons(pasted: "I said hello there", edited: "I said goodbye there") == []) // not a mishearing
        precondition(locate(before: "Hi. ", after: " Bye", in: "Hi. fixed text Bye") == "fixed text")
        precondition(locate(before: "Hi. ", after: "", in: "Hi. tail") == "tail")
        precondition(locate(before: "Hi. ", after: "", in: "") == nil)
        print("learn self-test passed")
    }
}
