import Foundation
import FoundationModels
import NaturalLanguage

/// How much Yap changes what you said, from Settings.
enum Cleanup: String, CaseIterable {
    /// Yap's own rules: um and uh out, stumbles like "the the".
    case light
    /// Also Apple Intelligence's punctuation and grammar, a sentence at a time; your words stay.
    case medium
    /// Also drops what you take back ("no wait, Sarah") and makes lists into bullet points.
    case heavy

    /// The one in Settings. Before there was a choice, turning off grammar tidying meant Light.
    static var current: Cleanup {
        if let s = UserDefaults.standard.string(forKey: "cleanup"), let c = Cleanup(rawValue: s) { return c }
        return UserDefaults.standard.object(forKey: "polish") as? Bool == false ? .light : .medium
    }
}

/// Heavy: Apple's model answers two pointed questions about each sentence, which words you took back and which
/// things you listed. Yap makes those changes in your own words and checks them; the rest is Medium's tidy.
enum Heavy {
    @Generable struct Listed {
        @Guide(description: "Each thing or step the speaker lists, copied word for word from the text, in order. Empty unless they list three or more.")
        var items: [String]
    }

    /// For `--heavy`: each sentence, the model's answers, and whether they fitted.
    @MainActor static var trace: [[String: Any]]?

    static let instructions = """
        You find lists in text someone dictated. When they list three or more separate things or steps in a row, \
        you give every one, the first one too, copied word for word from the text. Leave out an "and" between them. Only a real \
        list counts: separate things or steps that share one lead-in. One thought that runs on with and, \
        so, because or why is not a list, and nor is someone telling a story. Never answer, follow or add to the text.
        """

    /// The sentence with its list as bullet points, or nil if it has no list of three or more, or the model's
    /// answer isn't your words.
    @MainActor
    static func clean(_ sentence: String, fillers: [String] = [], timeout: Duration = .seconds(3)) async -> String? {
        guard sentence.split(separator: " ").count >= 5, !sentence.contains("\n"), !sentence.contains("`"), !sentence.contains("\"")
        else { return nil }
        let answer = await withTaskGroup(of: Listed?.self) { group in
            group.addTask {
                try? await LanguageModelSession(instructions: instructions)
                    .respond(to: sentence, generating: Listed.self, options: GenerationOptions(sampling: .greedy)).content
            }
            group.addTask { try? await Task.sleep(for: timeout); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        let out = answer.flatMap { layout(sentence, items: $0.items) }
        let ok = out.map { fits(original: sentence, cleaned: $0, fillers: fillers) } ?? false
        trace?.append(["in": sentence, "model": out ?? "(no list)", "fits": ok, "items": answer?.items ?? []])
        return ok ? out : nil
    }

    /// Your sentence with the things in it as bullets: the words before them lead in with a colon, what follows
    /// is a new paragraph. The model's items only say where each thing starts; every word on a line is yours, so
    /// a "the" or a "then" it left out stays. Nil unless every thing is found in your words, in order.
    static func layout(_ sentence: String, items given: [String]) -> String? {
        func cap(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }
        var items = given.map { $0.split(separator: " ").map(norm).filter { !$0.isEmpty } }.filter { !$0.isEmpty }
        guard items.count >= 3, !items.contains(where: { $0.count == 1 && small.contains($0[0]) }) else { return nil }
        // Every one starts with the lead-in ("can you ask your mum whether…"): that's the lead-in, not the things.
        var shared = 0
        while items.allSatisfy({ $0.count > shared + 1 && $0[shared] == items[0][shared] }) { shared += 1 }
        if shared > 0 { items = items.map { Array($0[shared...]) } }
        // "Bring a pack of cards", "the dice games", "that box set": the first one took the lead-in.
        let determiners: Set<String> = ["a", "an", "the", "some", "that", "those", "this", "these", "my", "your", "our"]
        if items.dropFirst().allSatisfy({ determiners.contains($0[0]) }), !determiners.contains(items[0][0]),
           let i = items[0].dropFirst().firstIndex(where: determiners.contains) {
            items[0] = Array(items[0][i...])
        }
        // "Can you check whether the cafe opens early", "whether they do decaf"…: the first one took the lead-in.
        if let w = items[1].first, items.dropFirst().allSatisfy({ $0.first == w }), let i = items[0].dropFirst().firstIndex(of: w) {
            items[0] = Array(items[0][i...])
        }
        let words = sentence.split(separator: " ").map(String.init), low = words.map(norm)
        func find(_ item: [String], from: Int) -> (Int, Int)? {
            // As said, or without a word or two the model put on the front ("check whether pets are allowed").
            for drop in 0..<min(3, item.count) {
                let w = Array(item[drop...])
                if let i = (from..<max(from, low.count - w.count + 1)).first(where: { Array(low[$0..<($0 + w.count)]) == w }) {
                    return (i, i + w.count)
                }
            }
            return nil
        }
        var spans: [(Int, Int)] = [], at = 0
        for item in items {
            guard let r = find(item, from: at) else { return nil }
            spans.append(r); at = r.1
        }
        // A real list: only joining words between the things ("and", "then", a "the"), and none of them a phrase
        // that carries on the one before ("climbing on Saturday morning" is not three things).
        let joining: Set<String> = ["and", "or", "then", "finally", "first", "next", "lastly", "also", "plus", "a", "an", "the",
                                    "some", "my", "your", "our", "whether", "after", "that", ""]
        for i in spans.indices.dropFirst() where !low[spans[i - 1].1..<spans[i].0].allSatisfy(joining.contains) { return nil }
        let carry: Set<String> = ["on", "in", "at", "with", "about", "to", "for", "by", "from", "of", "so", "because", "before",
                                  "after", "until", "but", "which", "who", "if", "when", "than", "as", "into", "was", "is", "are", "were", "be"]
        let firsts = spans.map { low[$0.0] }
        if firsts.contains(where: carry.contains) && !firsts.allSatisfy({ $0 == firsts[0] }) { return nil }
        // "Could: the cache, be holding…": a lead-in doesn't stop on a word that needs the rest of the sentence.
        if spans[0].0 > 0, ["could", "can", "is", "are", "do", "does", "did", "will", "would", "should", "have", "has", "was",
                            "were", "be"].contains(low[spans[0].0 - 1]) {
            return nil
        }
        // The first thing starts at a "the", "whether" or "first" just before it; each later one where the one
        // before it ended, so words between belong to the next.
        var start = spans[0].0
        while start > 0, ["a", "an", "the", "some", "that", "those", "this", "these", "my", "your", "our", "whether", "if", "first"]
            .contains(low[start - 1]) { start -= 1 }
        // Steps said with "first… then… finally" are a list as they are. Anything else needs what a list sounds
        // like: a lead-in ("we need"), an "and" or a comma before the last thing, and things rather than single
        // actions or descriptions ("ran, jumped and scrambled", "long, cold and miserable" stay as you said them).
        let stepped = (0..<spans[spans.count - 1].1).contains { ["then", "finally", "lastly"].contains(low[$0]) }
        if !stepped {
            // With no lead-in, only things to do ("mow the lawn, clear the gutters…"), and never a question
            // ("are you coming and are you bringing Sam?" stays one).
            guard start > 0 || (!sentence.hasSuffix("?") && items.allSatisfy { $0.count > 1 }) else { return nil }
            let n = spans.count, lastGap = low[spans[n - 2].1..<spans[n - 1].0]
            guard lastGap.contains("and") || lastGap.contains("or") || words[spans[n - 2].1 - 1].hasSuffix(",") else { return nil }
            let tagger = NLTagger(tagSchemes: [.lexicalClass])
            tagger.string = sentence
            var from = sentence.startIndex, single = 0, doing = 0
            for (i, span) in spans.enumerated() where span.1 - span.0 == 1 && items[i].count == 1 {
                guard let r = sentence.range(of: words[span.0], range: from..<sentence.endIndex) else { continue }
                from = r.upperBound
                single += 1
                if let tag = tagger.tag(at: r.lowerBound, unit: .word, scheme: .lexicalClass).0, [.verb, .adjective, .adverb].contains(tag) {
                    doing += 1
                }
            }
            if single >= 2, doing * 2 > single { return nil }
        }
        var froms = [start] + spans.dropLast().map { $0.1 }
        froms[0] = start
        let question = sentence.hasSuffix("?")
        let asks: Set<String> = ["is", "are", "does", "do", "did", "can", "could", "will", "would", "should", "what", "what's", "how",
                                 "how's", "who", "when", "where", "why", "which", "have", "has"]
        var lines: [String] = []
        for i in spans.indices {
            var line = Array(words[froms[i]..<spans[i].1])
            while let f = line.first, ["and", "or", "also", "plus"].contains(norm(f)) || norm(f).isEmpty { line.removeFirst() }
            guard !line.isEmpty else { return nil }
            var text = line.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ",;:. "))
            if question { text = text.trimmingCharacters(in: CharacterSet(charactersIn: "?")) }
            // Steps: "First, get the pasta on", "Then chop the garlic", "Finally, grate the parmesan".
            for step in ["first", "next", "finally", "lastly"] where norm(line[0]) == step && !line[0].hasSuffix(",") && line.count > 1 {
                text = line[0] + "," + text.dropFirst(line[0].count)
            }
            if question, asks.contains(norm(line[0])) { text += "?" }
            lines.append("- " + cap(text))
        }
        var lead = words[..<start].joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ",;:. "))
        var after = words[spans[spans.count - 1].1...].joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ",;:.?! "))
        if !lead.isEmpty { lead = cap(lead) + ":\n" }
        if !after.isEmpty { after = "\n\n" + cap(after) + (sentence.last.map { ".?!".contains($0) ? String($0) : "." } ?? ".") }
        return lead + lines.joined(separator: "\n") + after
    }

    // MARK: Taking back

    @Generable struct Correction {
        @Guide(description: "The words they took back, copied exactly from just before the correction words. Only the part they changed.")
        var tookBack: String
        @Guide(description: "The words they said instead, copied exactly from just after the correction words. Only the part that replaces it.")
        var instead: String
    }

    private static let correctionInstructions = """
        You help clean up dictated text. The speaker corrected themselves partway through. You say which words they \
        took back and which words they said instead, copying both exactly from the text.
        """
    /// Clear signals that what comes next replaces what came before. Unlike "actually" or "I mean", these are
    /// rarely anything else.
    static let takeBackSignals = ["no wait", "wait no", "scratch that", "scratch all that", "never mind", "nevermind", "nvm",
                                  "no wait i mean", "wait i mean", "no sorry i mean", "sorry i mean", "no i mean", "no sorry", "sorry no", "actually no", "no actually",
                                  "or rather", "let me rephrase", "make that", "sorry"]
        .sorted { $0.split(separator: " ").count > $1.split(separator: " ").count }
    /// After these, starting again with "let's…" or "I'll…" drops the whole idea before it.
    private static let restarts: Set<String> = ["no wait", "scratch that", "scratch all that", "never mind", "nevermind", "nvm",
                                                "actually no", "no actually", "let me rephrase"]
    private static let clauseStarts: Set<String> = ["i", "we", "you", "he", "she", "they", "let's", "i'll", "we'll", "i'd", "we'd", "i've", "i'm", "we're", "maybe"]
    /// Little words a correction usually doesn't say again: "by the front, no wait, side door" keeps "by the".
    private static let leadWords: Set<String> = ["to", "on", "at", "by", "in", "for", "from", "into", "the", "a", "an", "my", "your",
                                                 "our", "his", "her", "their", "this", "that", "some"]
    private static let small: Set<String> = ["the", "a", "an", "to", "it", "i", "you", "we", "they", "he", "she", "and", "of", "in",
                                             "on", "at", "for", "is", "be", "that", "this", "my", "your", "our", "with", "so", "just", "then"]

    /// The first signal in your words that really is a correction, as (where, how many words).
    private static func signal(in low: [String]) -> (Int, Int)? {
        for at in 1..<max(1, low.count) {
            guard let sg = takeBackSignals.lazy.map({ $0.split(separator: " ").map(String.init) })
                .first(where: { at + $0.count < low.count && Array(low[at..<(at + $0.count)]) == $0 }) else { continue }
            let said = sg.joined(separator: " "), prev = low[at - 1], next = low[at + sg.count]
            // "I'm sorry I snapped", "so sorry about that": an apology.
            if said == "sorry", ["i'm", "im", "am", "so", "really", "very", "be", "feel", "say"].contains(prev)
                || ["about", "for", "to", "but", "that"].contains(next) { continue }
            // "can't even answer a text, never mind commit to a weekend": let alone.
            if ["never mind", "nevermind"].contains(said),
               low[max(0, at - 8)..<at].contains(where: { ["even", "barely", "hardly", "can't", "cannot", "couldn't", "won't"].contains($0) }) { continue }
            // "or rather than driving": a choice, not a correction.
            if said == "or rather", next == "than" { continue }
            return (at, sg.count)
        }
        return nil
    }

    /// The sentence without what you took back. Apple's model says which words you took back and which you said
    /// instead; Yap takes out exactly those, and the signal. With no clear signal, or an answer that isn't your
    /// words, it's left as it was.
    @MainActor
    static func takeBack(_ sentence: String, timeout: Duration = .seconds(3)) async -> String {
        guard !sentence.contains("\"") else { return sentence }  // a quote is someone else's words
        var text = sentence
        for _ in 0..<3 {
            var words = text.split(separator: " ").map(String.init)
            let low = words.map(norm)
            guard let (at, length) = signal(in: low) else { break }
            // Someone else's words: "Dan goes, we'll ship it Friday, no wait, Monday" is a story, not a correction.
            // ("I said I'd collect it tonight, never mind…" is still you.)
            if (max(0, at - 15)..<at).contains(where: {
                ["says", "goes", "went", "told", "asked", "saying", "texted", "replied", "wrote"].contains(low[$0])
                    || (low[$0] == "said" && ($0 == 0 || low[$0 - 1] != "i"))
            }) { break }
            let said = low[at..<(at + length)].joined(separator: " ")
            let after = Array(low[(at + length)...])
            var cut: Int?

            if after.first == "not" {
                // "apples pears, no wait, not pears, plums": the words after "not" go from before, and so does "not …".
                if let k = (1...min(4, after.count - 1)).reversed().first(where: { k in
                       (max(0, at - 12)...(at - k)).contains { Array(low[$0..<($0 + k)]) == Array(after[1...k]) } }),
                   let j = (max(0, at - 12)...(at - k)).last(where: { Array(low[$0..<($0 + k)]) == Array(after[1...k]) }) {
                    words.removeSubrange(at..<(at + length + 1 + k))
                    words.removeSubrange(j..<(j + k))
                    text = words.joined(separator: " ")
                    continue
                }
                break
            }
            if restarts.contains(said), clauseStarts.contains(after.first ?? "") {
                // "We can cook when we get back, actually no, let's grab tacos": the idea before is gone.
                cut = 0
            } else {
                let question = """
                    Sentence: "\(text)"
                    They corrected themselves with "\(words[at..<(at + length)].joined(separator: " "))". \
                    What did they take back, and what did they say instead?
                    """
                let answer = await withTaskGroup(of: Correction?.self) { group in
                    group.addTask {
                        try? await LanguageModelSession(instructions: correctionInstructions)
                            .respond(to: question, generating: Correction.self, options: GenerationOptions(sampling: .greedy)).content
                    }
                    group.addTask { try? await Task.sleep(for: timeout); return nil }
                    let first = await group.next() ?? nil
                    group.cancelAll()
                    return first
                }
                trace?.append(["in": text, "signal": said, "took_back": answer?.tookBack ?? "(no answer)", "instead": answer?.instead ?? ""])
                var took = (answer?.tookBack ?? "").split(separator: " ").map(norm).filter { !$0.isEmpty }
                // It often copies the signal too: "glossy sorry I mean" took back "glossy".
                let sg = said.split(separator: " ").map(String.init)
                if let i = (0..<max(0, took.count - sg.count + 1)).first(where: { Array(took[$0..<($0 + sg.count)]) == sg }) {
                    took = Array(took[..<i])
                }
                var instead = (answer?.instead ?? "").split(separator: " ").map(norm).filter { !$0.isEmpty }
                if let i = (0..<max(0, instead.count - sg.count + 1)).first(where: { Array(instead[$0..<($0 + sg.count)]) == sg }) {
                    instead = Array(instead[(i + sg.count)...])
                }
                let answered = instead
                if !(instead.count <= after.count && Array(after.prefix(instead.count)) == instead) { instead = [] }
                let n = instead.isEmpty ? 1 : min(instead.count, 3)
                // In a list it often names the whole list; what's taken back is about as long as what replaces it.
                if took.count > n + 1 { took = Array(took.suffix(n)) }
                while let f = took.first, took.count > 1, leadWords.contains(f), after.first != f { took.removeFirst() }
                if !took.isEmpty, took.count <= at, Array(low[(at - took.count)..<at]) == took {
                    cut = at - took.count
                } else if !took.isEmpty, !instead.isEmpty,
                          let j = (max(0, at - 10)..<max(0, at - took.count)).last(where: { Array(low[$0..<($0 + took.count)]) == took }) {
                    // "two pizzas, no wait, three": what you said instead goes where the old words were.
                    let swapped = Array(words[(at + length)..<(at + length + instead.count)])
                    words.removeSubrange(at..<(at + length + instead.count))
                    words.replaceSubrange(j..<(j + took.count), with: swapped)
                    text = words.joined(separator: " ")
                    continue
                }
                // "Thursday morning, sorry, Friday morning": it ends the way what came before ended.
                if cut == nil, let k = (1...min(4, after.count)).first(where: { after[$0 - 1] == low[at - 1] }), k > 1, k <= at {
                    cut = at - k
                }
                // The correction starts by saying something again: "check the payment module, no wait, check the
                // search module". It replaces from there.
                let again = Array(after.prefix(small.contains(after.first ?? "") ? 2 : 1))
                if !again.isEmpty, at >= again.count, max(0, at - 12) <= at - again.count,
                   let j = (max(0, at - 12)...(at - again.count)).last(where: { Array(low[$0..<($0 + again.count)]) == again }),
                   j < (cut ?? at) {
                    // "Ask Felix to walk Miso, nvm, ask Leila": only the name changed, so the rest of what you
                    // asked stays ("Ask Leila to walk Miso").
                    let rest = Array(after.dropFirst(again.count))
                    let swap = answered.starts(with: again) ? Array(answered.dropFirst(again.count)) : answered
                    if (1...2).contains(swap.count), !clauseStarts.contains(swap[0]), swap[0] != "it", rest.starts(with: swap),
                       !took.isEmpty, took.count <= 2, let k = (j..<max(j, at - took.count + 1)).first(where: { Array(low[$0..<($0 + took.count)]) == took }) {
                        var new = Array(words[(at + length + again.count)..<(at + length + again.count + swap.count)])
                        // The full stop that ended "…get two." ends the sentence still.
                        if let p = new[new.count - 1].last, ".?!,".contains(p) {
                            new[new.count - 1].removeLast()
                            if !".?!,".contains(words[at - 1].last ?? " ") { words[at - 1].append(p) }
                        }
                        words.removeSubrange(at..<(at + length + again.count + swap.count))
                        words.replaceSubrange(k..<(k + took.count), with: new)
                        text = words.joined(separator: " ")
                        continue
                    }
                    cut = j
                }
                // No usable answer: a short correction stands in for as many words just before it ("downstairs,
                // sorry, I mean upstairs").
                if cut == nil, n <= 3, n < at {
                    var c = at - n
                    while c + 1 < at, leadWords.contains(low[c]), after.first != low[c] { c += 1 }
                    cut = c
                }
            }
            guard let cut else { break }
            words.removeSubrange(cut..<(at + length))
            if cut == 0, let first = words.first { words[0] = first.prefix(1).uppercased() + first.dropFirst() }
            text = words.joined(separator: " ")
        }
        return text
    }

    // MARK: The check

    /// Signals that what came just before is being taken back. Only these make it all right for words to go.
    static func norm(_ w: some StringProtocol) -> String {
        w.lowercased().replacingOccurrences(of: "’", with: "'").filter { $0.isLetter || $0.isNumber || $0 == "'" }
    }

    /// Nothing made up and nothing of yours lost: every word that's gone is a hesitation, a word that joins a list,
    /// or part of what you took back, in the 15 words before a signal like "no wait"; it added at most a word in
    /// ten; and a question is still a question unless you took it back.
    static func fits(original: String, cleaned: String, fillers: [String] = []) -> Bool {
        let a = original.split(whereSeparator: { $0 == " " || $0 == "-" }).map(norm).filter { !$0.isEmpty }
        let b = cleaned.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "\n" }).map(norm).filter { !$0.isEmpty }
        var count: [String: Int] = [:]
        for w in a { count[w, default: 0] += 1 }
        for w in b { count[w, default: 0] -= 1 }
        let added = count.values.filter { $0 < 0 }.reduce(0, -)
        // What you took back is already gone (takeBack): here the model may only take out hesitation sounds.
        var may = Set(Polish.builtInFillers + fillers.map { $0.lowercased() })
        if cleaned.contains("\n- ") || cleaned.hasPrefix("- ") { may.formUnion(["and", "or", "also", "then", "finally", "first", "plus"]) }
        let lost = count.filter { $0.value > 0 && !may.contains($0.key) }
        let questions = !original.contains("?") || cleaned.contains("?") || cleaned.contains("\n- ")
        return lost.isEmpty && added <= max(2, a.count / 10) && questions
    }

    static func selfTest() {
        precondition(!fits(original: "I really don't like it.", cleaned: "I don't like it."))                    // lost "really"
        precondition(!fits(original: "What should I do next?", cleaned: "You could start by writing the tests."))  // answered
        precondition(fits(original: "For the trip we need tickets, a charger and the passports.",
                          cleaned: "For the trip we need:\n- Tickets\n- A charger\n- The passports"))
        precondition(!fits(original: "Is this bad?", cleaned: "Is this bad."))
        precondition(!fits(original: "It got moved to three so the review will have to wait until after lunch.",
                           cleaned: "It got moved to three until after lunch."))
        let l = layout("For the trip we need tickets, a charger and the passports. See you then.", items: ["tickets", "a charger", "the passports"])
        precondition(l == "For the trip we need:\n- Tickets\n- A charger\n- The passports\n\nSee you then.", l ?? "nil")
        let st = layout("To reproduce it first open a workspace then import it and finally check the panel.",
                        items: ["open a workspace", "import it", "check the panel"])
        precondition(st == "To reproduce it:\n- First, open a workspace\n- Then import it\n- Finally, check the panel", st ?? "nil")
        precondition(layout("Bring the cake, the cups and plates.", items: ["cake", "forks", "plates"]) == nil)   // not your words
        print("heavy self-test passed")
    }
}
