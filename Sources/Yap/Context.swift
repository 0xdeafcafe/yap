import AppKit

/// Words from what you're looking at, for one dictation: the names and terms an app like rush sends over the live
/// socket, and the text in the focused window, read through Accessibility. They go to the recogniser as hints, and
/// a near miss of exactly one of them ("Reddis" with "Redis" on screen) is fixed and counted towards learning it.
/// Only the words picked out are kept, in memory, until the dictation's pasted; the screen's text never is.
enum Context {
    /// What one app said over the socket: the bundle id of the terminal it runs in ("" if it doesn't know) and its words.
    struct Client: Equatable {
        let app: String
        let words: [String]
        /// It puts a finished dictation in its own box and answers `{"took":…}` or `{"left":…}` (rush does).
        var takes = false
        /// It's in front with a box that takes the dictation, and shows the dictation there itself (rush does, while
        /// its tab is in front): while its app is in front, Yap shows nothing of its own.
        var shows = false
    }

    /// Whether the app in front (`front`, its bundle id) shows a dictation itself: one of the connected clients for
    /// it said `shows`. Never for an app Yap can't name, nor for a client that's gone (it isn't in `clients`).
    static func showsItself(front: String, clients: [Client]) -> Bool {
        !front.isEmpty && clients.contains { $0.shows && $0.app == front }
    }

    /// A client's answer to a done: it put the text in its box itself (took) or left it to the paste.
    struct Answer: Equatable {
        let took: Bool
        let text: String
    }

    static let maxLineBytes = 64 * 1024
    static let maxClientWords = 200

    /// `{"context":{"app":"com.mitchellh.ghostty","words":["Redis","rushd"]}}`, or nil for anything else.
    static func parseLine(_ line: Data) -> Client? {
        guard line.count <= maxLineBytes,
              let top = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let ctx = top["context"] as? [String: Any],
              let list = ctx["words"] as? [Any] else { return nil }
        let app = ctx["app"] as? String ?? ""
        let takes = ctx["takes"] as? Bool ?? false
        let shows = ctx["shows"] as? Bool ?? false
        var seen = Set<String>(), words: [String] = []
        for case let w as String in list {
            let w = w.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (2...48).contains(w.count), w.contains(where: \.isLetter), seen.insert(w).inserted else { continue }
            words.append(w)
            if words.count == maxClientWords { break }
        }
        return Client(app: app, words: words, takes: takes, shows: shows)
    }

    /// `{"took":"the text"}` or `{"left":"the text"}`, or nil for anything else.
    static func parseAnswer(_ line: Data) -> Answer? {
        guard line.count <= maxLineBytes,
              let top = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return nil }
        if let t = top["took"] as? String { return Answer(took: true, text: t) }
        if let t = top["left"] as? String { return Answer(took: false, text: t) }
        return nil
    }

    // MARK: Reading the screen

    /// The focused element's text and the static text in the focused window, at most `limit` characters and about
    /// `budget` seconds. Call off the main thread. Password boxes are never read.
    nonisolated static func screenText(limit: Int = 20_000, budget: TimeInterval = 0.05) -> String {
        guard AXIsProcessTrusted() else { return "" }
        let deadline = Date().addingTimeInterval(budget)
        func remaining() -> Float { Float(max(0.01, deadline.timeIntervalSinceNow)) }
        func get(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
            AXUIElementSetMessagingTimeout(e, remaining())
            var v: CFTypeRef?
            return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
        }
        func secure(_ e: AXUIElement) -> Bool { get(e, kAXSubroleAttribute) as? String == kAXSecureTextFieldSubrole }
        var out = ""
        func add(_ s: String, tail: Bool = false) {
            let room = limit - out.utf16.count
            guard room > 0, !s.isEmpty else { return }
            out += (tail ? String(s.suffix(room)) : String(s.prefix(room))) + "\n"
        }
        guard let appRef = get(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute),
              CFGetTypeID(appRef) == AXUIElementGetTypeID() else { return "" }
        let app = appRef as! AXUIElement
        // The box you're typing in: its end is nearest what you're doing (a terminal's latest output).
        if let f = get(app, kAXFocusedUIElementAttribute), CFGetTypeID(f) == AXUIElementGetTypeID() {
            let field = f as! AXUIElement
            if !secure(field), let v = get(field, kAXValueAttribute) as? String { add(v, tail: true) }
        }
        guard let w = get(app, kAXFocusedWindowAttribute), CFGetTypeID(w) == AXUIElementGetTypeID() else { return out }
        var queue = [w as! AXUIElement], visited = 0
        while !queue.isEmpty, visited < 2000, out.utf16.count < limit, Date() < deadline {
            let e = queue.removeFirst(); visited += 1
            if get(e, kAXRoleAttribute) as? String == kAXStaticTextRole {
                if let v = get(e, kAXValueAttribute) as? String { add(v) }
                continue
            }
            if let kids = get(e, kAXChildrenAttribute) as? [AXUIElement] { queue += kids.prefix(200) }
        }
        return out
    }

    /// Reads the screen on another thread, giving up after `timeout` so a hung app never holds a dictation up.
    static func readScreen(timeout: TimeInterval = 0.15) async -> String {
        await withCheckedContinuation { (cont: CheckedContinuation<String, Never>) in
            let lock = NSLock(); var done = false
            func finish(_ s: String) { lock.lock(); defer { lock.unlock() }; if !done { done = true; cont.resume(returning: s) } }
            DispatchQueue.global(qos: .userInitiated).async { finish(screenText()) }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish("") }
        }
    }

    // MARK: Picking words

    /// Words worth hearing: a client's, then the screen's most frequent, the screen ones capped at `screenCap`.
    /// `yapSaid`: words in Yap's own recent transcripts. One that's a near miss of another context word is likely an
    /// old mishearing still on screen ("Reddis" above "Redis"), so it's left out rather than taught to the recogniser.
    @MainActor
    static func hints(client: [String], screen: String, yapSaid: Set<String> = [], language: String, screenCap: Int = 100) -> [String] {
        var counts: [String: Int] = [:], order: [String] = []
        for w in tokens(screen) where plausible(w) {
            if counts[w] == nil { order.append(w) }
            counts[w, default: 0] += 1
        }
        let fromClient = client.filter(plausible)
        let candidates = Array(order.prefix(3000)) + fromClient
        let unknown = unknownWords(candidates + candidates.filter { $0.first?.isUppercase == true }.map { $0.lowercased() }, language: language)
        func keep(_ w: String) -> Bool {
            let lower = w.lowercased()
            if w.dropFirst().contains(where: \.isLowercase) && w.dropFirst().contains(where: \.isUppercase) { return true } // LangWatch, iOS
            if w.contains(where: \.isNumber) { return true }                                                               // k8s
            if w.first?.isUppercase == true { return unknown.contains(lower) }    // a name or acronym: "london", "aws" aren't words
            return unknown.contains(w)                                            // rushd
        }
        let clientKept = fromClient.filter(keep)
        let screenAll = order.filter(keep).sorted { counts[$0]! > counts[$1]! }
        let screenKept = screenAll.filter { w in
            guard yapSaid.contains(w.lowercased()) else { return true }
            return !(clientKept + screenAll).contains { c in c != w && !yapSaid.contains(c.lowercased()) && close(w, c) }
        }
        return dedupe(clientKept + screenKept.prefix(screenCap))
    }

    /// Your words and learned words first, then the context's, at most `cap` in all and `contextCap` from the context.
    static func merge(_ terms: [String], _ context: [String], cap: Int = 300, contextCap: Int = 100) -> [String] {
        let mine = dedupe(terms)
        let have = Set(mine.map { $0.lowercased() })
        let extra = dedupe(context).filter { !have.contains($0.lowercased()) }.prefix(contextCap)
        return Array((mine + extra).prefix(max(cap, mine.count)))
    }

    private static func dedupe(_ words: [String]) -> [String] {
        var seen = Set<String>()
        return words.filter { seen.insert($0.lowercased()).inserted }
    }

    /// Something you could say: letters (digits allowed), 3 to 30 long, not a hash.
    private static func plausible(_ w: String) -> Bool {
        guard (3...30).contains(w.count), w.first?.isLetter == true, w.allSatisfy({ $0.isLetter || $0.isNumber }) else { return false }
        let digits = w.filter(\.isNumber).count
        if digits > 0 && (w.count > 6 || digits * 2 > w.count) { return false }                  // a9b7ecfe, v1234
        return true
    }

    private static func tokens(_ s: String) -> [String] {
        s.split(whereSeparator: { !($0.isLetter || $0.isNumber) }).map(String.init)
    }

    /// The ones macOS's dictionary doesn't know in your spelling or the other one, so "gray" and "colour" are both
    /// words. One pass of the spelling checker over them all, then the other spelling over what it flagged.
    @MainActor
    static func unknownWords(_ words: [String], language: String) -> Set<String> {
        func flagged(_ words: Set<String>, _ language: String) -> Set<String> {
            guard !words.isEmpty else { return [] }
            let joined = words.joined(separator: " "), ns = joined as NSString
            var out = Set<String>(), start = 0
            while start < ns.length {
                let r = NSSpellChecker.shared.checkSpelling(of: joined, startingAt: start, language: language, wrap: false,
                                                            inSpellDocumentWithTag: 0, wordCount: nil)
                guard r.location != NSNotFound, r.location >= start, r.length > 0 else { break }
                out.insert(ns.substring(with: r)); start = r.upperBound
            }
            return out
        }
        let other = language == "en_US" ? "en_GB" : "en_US"
        return flagged(flagged(Set(words), language), other)
    }

    /// Known to macOS's dictionary in either case, or one of your words: never swapped.
    @MainActor
    static func knownCheck(for text: String, yours: Set<String>, language: String) -> (String) -> Bool {
        let ws = tokens(text)
        let unknown = unknownWords(ws + ws.map { $0.lowercased() }, language: language)
        return { w in yours.contains(w.lowercased()) || !unknown.contains(w) || !unknown.contains(w.lowercased()) }
    }

    // MARK: Fixing near misses

    /// Same first letter and close enough by Learn's measure for a mishearing, or the same letters in other capitals.
    static func close(_ said: String, _ meant: String) -> Bool {
        let a = said.lowercased(), b = meant.lowercased()
        if a == b { return said != meant }
        return meant.count >= 3 && a.first == b.first && Learn.distance(a, b) <= max(1, Int(0.4 * Double(meant.count)))
    }

    /// Fixes words in `text` that are a near miss of exactly one context word, and what that teaches. Two or three
    /// words that squash into one ("lang watch" → "LangWatch") are joined; a single word is only swapped when the
    /// dictionary and your words don't know it, so "gray" never becomes anything else.
    static func fix(_ text: String, context: [String], isKnown: (String) -> Bool) -> (text: String, lessons: [Learn.Lesson]) {
        let targets = dedupe(context.filter { $0.count >= 2 && $0.allSatisfy { $0.isLetter || $0.isNumber } })
        guard !targets.isEmpty, !text.isEmpty else { return (text, []) }
        var byLower: [String: String] = [:]
        for t in targets { byLower[t.lowercased()] = t }
        let ns = text as NSString
        let re = try! NSRegularExpression(pattern: #"[\p{L}\p{N}]+(?:['’][\p{L}]+)?"#)
        let matches = re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map(\.range)
        var edits: [(range: NSRange, now: String)] = [], lessons: [Learn.Lesson] = []
        var i = 0
        while i < matches.count {
            // Two or three words, a space apart, that are one context word squashed.
            var joined = false
            for n in [3, 2] where i + n <= matches.count {
                let span = matches[i..<(i + n)]
                let gapsAreSpaces = zip(span, span.dropFirst()).allSatisfy { a, b in
                    ns.substring(with: NSRange(location: a.upperBound, length: b.location - a.upperBound)) == " "
                }
                guard gapsAreSpaces else { continue }
                let words = span.map { ns.substring(with: $0) }
                let squashed = words.joined()
                guard let now = byLower[squashed.lowercased()] else { continue }
                let range = NSRange(location: span.first!.location, length: span.last!.upperBound - span.first!.location)
                let was = words.joined(separator: " ")
                edits.append((range, now))
                lessons += Learn.lesson(was: was, now: now)
                i += n; joined = true
                break
            }
            if joined { continue }
            let r = matches[i]; i += 1
            let w = ns.substring(with: r)
            guard w.count >= 3, !w.contains("'"), !w.contains("’"), !isKnown(w) else { continue }
            let now: String
            if let exact = byLower[w.lowercased()] {
                guard exact != w else { continue }
                now = exact
            } else {
                let near = targets.filter { close(w, $0) }
                guard near.count == 1 else { continue }
                now = near[0]
            }
            edits.append((r, now))
            lessons += Learn.lesson(was: w, now: now)
        }
        guard !edits.isEmpty else { return (text, []) }
        let out = NSMutableString(string: text)
        for e in edits.reversed() { out.replaceCharacters(in: e.range, with: e.now) }
        return (out as String, lessons)
    }

    @MainActor
    static func selfTest() {
        let lang = "en_US"
        func fixed(_ text: String, _ ctx: [String]) -> (text: String, lessons: [Learn.Lesson]) {
            fix(text, context: ctx, isKnown: knownCheck(for: text, yours: [], language: lang))
        }
        let reddis = fixed("restart Reddis now", ["Redis", "rushd"])
        precondition(reddis.text == "restart Redis now", "Reddis: \(reddis.text)")
        precondition(reddis.lessons == [.swap("Reddis", "Redis", 3)], "Reddis lessons: \(reddis.lessons)")
        precondition(fixed("the gray cat", ["Grey", "Gray", "Grai", "Grax"]).text == "the gray cat")     // a dictionary word
        let lang2 = fixed("ping lang watch now", ["LangWatch"])
        precondition(lang2.text == "ping LangWatch now", "lang watch: \(lang2.text)")
        precondition(lang2.lessons == [.term("LangWatch"), .swap("lang watch", "LangWatch", 2)])
        precondition(fixed("restart Reddis now", []).text == "restart Reddis now")                      // no context
        precondition(fixed("restart Reddis now", ["Redis", "Reddit"]).text == "restart Reddis now")     // two near: unsure
        precondition(fixed("run rushd", ["rushd"]).text == "run rushd")                                  // already right
        precondition(fixed("the langwatch app", ["LangWatch"]).text == "the LangWatch app")
        precondition(parseLine(Data(#"{"context":{"app":"com.mitchellh.ghostty","words":["Redis","rushd","LangWatch"]}}"#.utf8))
                     == Client(app: "com.mitchellh.ghostty", words: ["Redis", "rushd", "LangWatch"]))
        precondition(parseLine(Data(#"{"context":{"words":["Redis"," ","x",7,"Redis"]}}"#.utf8)) == Client(app: "", words: ["Redis"]))
        precondition(parseLine(Data(#"{"phase":"listening"}"#.utf8)) == nil)
        precondition(parseLine(Data(#"{"context":{"app":"","words":[],"takes":true}}"#.utf8)) == Client(app: "", words: [], takes: true))
        precondition(parseLine(Data(#"{"context":{"app":"com.mitchellh.ghostty","words":[],"takes":true,"shows":true}}"#.utf8))
                     == Client(app: "com.mitchellh.ghostty", words: [], takes: true, shows: true))
        precondition(parseLine(Data(#"{"context":{"app":"a","words":[],"shows":"yes"}}"#.utf8))?.shows == false)
        // Showing it itself: only the app in front, with a connected client for it that said shows.
        let rush = Client(app: "com.mitchellh.ghostty", words: [], takes: true, shows: true)
        let behind = Client(app: "com.mitchellh.ghostty", words: [], takes: true)
        precondition(showsItself(front: "com.mitchellh.ghostty", clients: [behind, rush]))               // in front, shows
        precondition(!showsItself(front: "com.mitchellh.ghostty", clients: [behind]))                    // in front, doesn't
        precondition(!showsItself(front: "com.mitchellh.ghostty", clients: []))                          // gone (rush quit)
        precondition(!showsItself(front: "com.apple.Notes", clients: [rush]))                            // another app in front
        precondition(!showsItself(front: "", clients: [Client(app: "", words: [], shows: true)]))        // can't tell
        precondition(parseAnswer(Data(#"{"took":"ship it"}"#.utf8)) == Answer(took: true, text: "ship it"))
        precondition(parseAnswer(Data(#"{"left":"ship it"}"#.utf8)) == Answer(took: false, text: "ship it"))
        precondition(parseAnswer(Data(#"{"context":{"words":[]}}"#.utf8)) == nil)
        precondition(parseLine(Data("not json".utf8)) == nil)
        let many = (0..<300).map { "\"w\($0)x\"" }.joined(separator: ",")
        precondition(parseLine(Data("{\"context\":{\"app\":\"\",\"words\":[\(many)]}}".utf8))?.words.count == maxClientWords)
        precondition(parseLine(Data(("{\"context\":{\"words\":[\"" + String(repeating: "a", count: maxLineBytes) + "\"]}}").utf8)) == nil)
        let hinted = hints(client: ["Redis"], screen: "error: the LangWatch build at a9b7ecfe failed. ERROR Reddis rushd k8s and the gray cat", yapSaid: ["reddis"], language: lang)
        precondition(hinted.contains("Redis") && hinted.contains("LangWatch") && hinted.contains("rushd") && hinted.contains("k8s"), "hints: \(hinted)")
        precondition(!hinted.contains("Reddis") && !hinted.contains("gray") && !hinted.contains("ERROR") && !hinted.contains("a9b7ecfe"), "hints: \(hinted)")
        precondition(merge(["LangWatch"], ["langwatch", "Redis"]) == ["LangWatch", "Redis"])
        precondition(merge(["a1"], (0..<500).map { "w\($0)" }).count == 101)
        print("context self-test passed")
    }
}
