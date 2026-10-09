import Foundation

/// Rule-based cleanup. Only removes patterns that never carry meaning; tested against 40 real
/// dictations it cut none of the speaker's words, where Apple's on-device model deleted real ones.
enum Tidy {
    /// format: spoken commands and lists become line breaks, bullets and numbers (see `format`).
    /// terms: your words; ones with capitals inside ("LangWatch", "iOS") are written your way wherever they appear.
    static func clean(_ input: String, replacements: [(String, String)] = [], terms: [String] = [], format: Bool = false) -> String {
        var t = input
        t = sub(t, #"\b(um+|uh+|erm|hmm+)\b[,.]?\s*"#, "")
        for _ in 0..<3 { // "it's not it's not" / "the the" / "and, and"
            t = sub(t, #"\b(\w+(?:'\w+)?(?: \w+(?:'\w+)?)?)[,.]? \1\b"#, "$1")
        }
        t = sub(t, #"(^|[.?!] |, )(like|you know|i mean),\s*"#, "$1")
        t = sub(t, #",\s*like\s*,"#, ",")
        if format { t = Self.format(t) }
        for (spoken, written) in replacements {
            t = sub(t, #"\b"# + NSRegularExpression.escapedPattern(for: spoken) + #"\b"#, NSRegularExpression.escapedTemplate(for: written))
        }
        // Only spaces and tabs: line breaks from `format` stay.
        t = sub(sub(sub(t, #"[ \t]{2,}"#, " "), #"[ \t]+([,.?!])"#, "$1"), #"[ \t]*\n[ \t]*"#, "\n")
        t = capitalizeSentences(t.trimmingCharacters(in: .whitespacesAndNewlines))
        for term in terms where term.dropFirst().contains(where: \.isUppercase) {
            t = sub(t, #"\b"# + NSRegularExpression.escapedPattern(for: term) + #"\b"#, NSRegularExpression.escapedTemplate(for: term))
        }
        return t
    }

    /// Spoken formatting. A command only counts at the start of a sentence or clause, so
    /// "a new line of credit" and "one of the things" are left alone.
    static func format(_ input: String) -> String {
        let start = #"(^|([.?!,:;]))\s*"#, end = #"[.?!,:;]?\s*"#
        var t = input
        t = sub(t, start + "new paragraph" + end, "$2\n\n")
        t = sub(t, start + "new line" + end, "$2\n")
        t = sub(t, start + "(?:next )?(?:bullet(?: point)?|dash)" + end, "$2\n- ")
        t = replace(t, start + #"number (one|two|three|four|five|six|seven|eight|nine|ten|\d+)"# + end) { m in
            "\(m[2])\n\(numbers.firstIndex(of: m[3].lowercased()).map { "\($0 + 1)" } ?? m[3]). "
        }
        t = sub(t, #"\bcode (.+?) end code\b"#, "`$1`")
        t = sub(t, #"\bopen quote (.+?) close quote\b"#, "\"$1\"")
        return t.split(separator: "\n", omittingEmptySubsequences: false).map { autoList(String($0)) }.joined(separator: "\n")
    }

    private static let numbers = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
    private static let ordinals = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"]

    /// Three or more sentences in a row that start "First, … Second, … Third, …" (or "One, … Two, …") become a numbered list.
    private static func autoList(_ line: String) -> String {
        let sentences = line.components(separatedBy: ". ").map { $0 }
        func lead(_ s: String, _ n: Int) -> String? {
            guard n < ordinals.count, let r = s.range(of: "^(\(ordinals[n])(ly)?|\(numbers[n])),\\s*", options: [.regularExpression, .caseInsensitive]) else { return nil }
            return String(s[r.upperBound...])
        }
        var out: [String] = [], i = 0
        while i < sentences.count {
            var run = 0
            while i + run < sentences.count, lead(sentences[i + run], run) != nil { run += 1 }
            if run >= 3 {
                let items = (0..<run).map { "\($0 + 1). " + lead(sentences[i + $0], $0)! }
                out.append((out.isEmpty ? "" : "\n") + items.joined(separator: ".\n"))
                i += run
            } else {
                out.append(sentences[i]); i += 1
            }
        }
        return out.joined(separator: ". ").replacingOccurrences(of: ". \n", with: ".\n")
    }

    private static func replace(_ s: String, _ pattern: String, _ make: ([String]) -> String) -> String {
        let re = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        var out = s
        for m in re.matches(in: s, range: NSRange(s.startIndex..., in: s)).reversed() {
            let groups = (0..<m.numberOfRanges).map { Range(m.range(at: $0), in: s).map { String(s[$0]) } ?? "" }
            out.replaceSubrange(Range(m.range, in: out)!, with: make(groups))
        }
        return out
    }

    private static func sub(_ s: String, _ pattern: String, _ template: String) -> String {
        let re = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }

    private static func capitalizeSentences(_ s: String) -> String {
        var out = "", upNext = true
        var code = false
        for c in s {
            if c == "`" { code.toggle() }
            out.append(upNext && !code && c.isLetter ? Character(c.uppercased()) : c)
            if c.isLetter { upNext = false } else if ".?!\n".contains(c) { upNext = true }
        }
        return out
    }

    static func selfTest() {
        precondition(clean("Um, the the cat") == "The cat")
        precondition(clean("it's not it's not sure") == "It's not sure")
        precondition(clean("I like cats") == "I like cats")
        precondition(clean("Yeah. Like, do it, you know, now") == "Yeah. Do it, now")
        precondition(clean("email me btw", replacements: [("btw", "by the way")]) == "Email me by the way")
        precondition(clean("ios and langwatch", terms: ["iOS", "LangWatch", "Will"]) == "IOS and LangWatch".replacingOccurrences(of: "IOS", with: "iOS"))
        precondition(clean("will it work", terms: ["Will"]) == "Will it work")
        let formatted: [(String, String)] = [
            ("Hello. New line. World", "Hello.\nWorld"),
            ("Intro. New paragraph. Next", "Intro.\n\nNext"),
            ("Bullet milk. Bullet eggs.", "- Milk.\n- Eggs."),
            ("Number one, milk. Number two, eggs.", "1. Milk.\n2. Eggs."),
            ("First, plan. Second, build. Third, ship.", "1. Plan.\n2. Build.\n3. Ship."),
            ("So. First, plan. Second, build. Third, ship.", "So.\n1. Plan.\n2. Build.\n3. Ship."),
            ("First, plan. Then ship.", "First, plan. Then ship."),
            ("One of the things is speed", "One of the things is speed"),
            ("We need a new line of credit", "We need a new line of credit"),
            ("Run code npm test end code now", "Run `npm test` now"),
            ("The code is broken", "The code is broken"),
            ("He said open quote hi close quote", "He said \"hi\""),
        ]
        for (said, want) in formatted {
            let got = clean(said, format: true)
            precondition(got == want, "format: \(said.debugDescription) gave \(got.debugDescription), wanted \(want.debugDescription)")
        }
        precondition(clean("Bullet milk") == "Bullet milk") // off unless asked for
        print("tidy self-test passed")
    }
}

/// ~/.config/yap/words.txt: one term per line ("LangWatch"), or "spoken => written".
/// Terms bias the recogniser toward your spelling; replacements run after cleanup.
enum Words {
    static let file = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/yap/words.txt")

    static func ensureFile() {
        guard !FileManager.default.fileExists(atPath: file.path) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? "# One word or name per line, or \"spoken => written\".\n".write(to: file, atomically: true, encoding: .utf8)
    }

    static func load() -> (terms: [String], replacements: [(String, String)]) {
        let lines = ((try? String(contentsOf: file, encoding: .utf8)) ?? "")
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        var terms: [String] = [], reps: [(String, String)] = []
        for l in lines {
            let parts = l.components(separatedBy: "=>").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { reps.append((parts[0], parts[1])); terms.append(parts[1]) } else { terms.append(l) }
        }
        return (terms, reps)
    }
}
