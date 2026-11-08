import Foundation

/// Formatted dictation as an app wants it. Inside Yap, bold is `**said**`; bullets ("- "), numbers ("1. "),
/// to-dos ("- [ ] ") and paragraphs are on lines of their own. Plain text keeps those but loses the asterisks;
/// HTML, for apps that take it (Notes, Mail, Slack, Docs), has real bold and real lists.
enum Rich {
    /// Whether there's anything HTML would show better than plain text.
    static func isFormatted(_ text: String) -> Bool {
        text.contains("**") || text.contains("`") || text.split(separator: "\n").contains { kind(of: String($0)) != nil }
    }

    /// Without the bold markers: what's shown, saved and pasted where formatting can't go.
    static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
    }

    private enum Line: Equatable { case bullet, number, todo }

    /// What a line is, and the words after its marker.
    private static func kind(of line: String) -> (Line, String)? {
        if line.hasPrefix("- [ ] ") { return (.todo, String(line.dropFirst(6))) }
        if line.hasPrefix("- ") { return (.bullet, String(line.dropFirst(2))) }
        if let r = line.range(of: #"^\d+\. "#, options: .regularExpression) { return (.number, String(line[r.upperBound...])) }
        return nil
    }

    /// No fonts or sizes: the app you paste into uses its own.
    static func html(_ text: String) -> String {
        var out = "", open: Line?
        func close() {
            if let o = open { out += o == .number ? "</ol>" : "</ul>" }
            open = nil
        }
        for paragraph in text.components(separatedBy: "\n\n") {
            var prose: [String] = []
            func flush() { if !prose.isEmpty { out += "<p>" + prose.joined(separator: "<br>") + "</p>"; prose = [] } }
            for line in paragraph.components(separatedBy: "\n") where !line.isEmpty {
                if let (k, words) = kind(of: line) {
                    flush()
                    if open != k { close(); out += k == .number ? "<ol>" : "<ul>"; open = k }
                    out += "<li>" + (k == .todo ? "☐ " : "") + inline(words) + "</li>"
                } else {
                    close()
                    prose.append(inline(line))
                }
            }
            close(); flush()
        }
        return "<meta charset=\"utf-8\">" + out
    }

    /// Escaped, with **bold** and `code`.
    private static func inline(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        t = t.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<b>$1</b>", options: .regularExpression)
        t = t.replacingOccurrences(of: #"`(.+?)`"#, with: "<code>$1</code>", options: .regularExpression)
        return t
    }

    static func selfTest() {
        precondition(!isFormatted("Just a sentence. And another."))
        precondition(isFormatted("Ship it **today**"))
        precondition(isFormatted("Few things:\n- Milk\n- Eggs"))
        precondition(plain("Ship it **today** and **now**") == "Ship it today and now")
        let h = html("Few things:\n- Milk\n- **Eggs**\n\nThen:\n1. Plan\n2. Ship <it>\n\n- [ ] Call Jake")
        precondition(h == "<meta charset=\"utf-8\"><p>Few things:</p><ul><li>Milk</li><li><b>Eggs</b></li></ul><p>Then:</p><ol><li>Plan</li><li>Ship &lt;it&gt;</li></ol><ul><li>☐ Call Jake</li></ul>", h)
        print("rich self-test passed")
    }
}
