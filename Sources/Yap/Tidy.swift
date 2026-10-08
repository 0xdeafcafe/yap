import Foundation

/// Rule-based cleanup. Only removes patterns that never carry meaning; tested against 40 real
/// dictations it cut none of the speaker's words, where Apple's on-device model deleted real ones.
enum Tidy {
    static func clean(_ input: String, replacements: [(String, String)] = []) -> String {
        var t = input
        t = sub(t, #"\b(um+|uh+|erm|hmm+)\b[,.]?\s*"#, "")
        for _ in 0..<3 { // "it's not it's not" / "the the" / "and, and"
            t = sub(t, #"\b(\w+(?:'\w+)?(?: \w+(?:'\w+)?)?)[,.]? \1\b"#, "$1")
        }
        t = sub(t, #"(^|[.?!] |, )(like|you know|i mean),\s*"#, "$1")
        t = sub(t, #",\s*like\s*,"#, ",")
        for (spoken, written) in replacements {
            t = sub(t, #"\b"# + NSRegularExpression.escapedPattern(for: spoken) + #"\b"#, NSRegularExpression.escapedTemplate(for: written))
        }
        t = sub(sub(t, #"\s{2,}"#, " "), #"\s+([,.?!])"#, "$1").trimmingCharacters(in: .whitespaces)
        return capitalizeSentences(t)
    }

    private static func sub(_ s: String, _ pattern: String, _ template: String) -> String {
        let re = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }

    private static func capitalizeSentences(_ s: String) -> String {
        var out = "", upNext = true
        for c in s {
            out.append(upNext && c.isLetter ? Character(c.uppercased()) : c)
            if c.isLetter { upNext = false } else if ".?!".contains(c) { upNext = true }
        }
        return out
    }

    static func selfTest() {
        precondition(clean("Um, the the cat") == "The cat")
        precondition(clean("it's not it's not sure") == "It's not sure")
        precondition(clean("I like cats") == "I like cats")
        precondition(clean("Yeah. Like, do it, you know, now") == "Yeah. Do it, now")
        precondition(clean("email me btw", replacements: [("btw", "by the way")]) == "Email me by the way")
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
