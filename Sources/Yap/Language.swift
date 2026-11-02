import AppKit
import FoundationModels
import Speech

/// The language you dictate in, as a locale identifier ("en_GB", "pt_BR"). Apple's recogniser decides
/// which ones exist; macOS's spelling checker and the on-device model each cover their own set.
enum Language {
    /// The one in Settings, else your Mac's (see `registerDefault`).
    static var current: String { UserDefaults.standard.string(forKey: "locale") ?? Dictation.defaultLocale }

    /// Your Mac's own language, if the recogniser knows it, else British or American English, decided once at launch.
    /// Registered rather than saved, so it follows your Mac until you pick one in Settings.
    static func registerDefault() async {
        let supported = await SpeechTranscriber.supportedLocales.map(\.identifier)
        let id = pick(preferred: Locale.preferredLanguages, region: Locale.current.region?.identifier, supported: supported)
        UserDefaults.standard.register(defaults: ["locale": id])
    }

    /// The first of your Mac's languages the recogniser knows: in that region ("pt-BR" → pt_BR), else the
    /// language's home one ("fr" → fr_FR, not Swiss French). English in a region without its own is American,
    /// unless you're in the UK.
    static func pick(preferred: [String], region: String?, supported: [String]) -> String {
        for tag in preferred {
            let l = Locale(identifier: tag)
            guard let code = l.language.languageCode?.identifier else { continue }
            let home = Locale(identifier: Locale(identifier: code).language.maximalIdentifier).region?.identifier
            for r in [l.region?.identifier ?? region, home].compactMap({ $0 }) where supported.contains("\(code)_\(r)") {
                return "\(code)_\(r)"
            }
        }
        return Dictation.defaultLocale
    }

    static func selfTest() {
        let s = ["en_GB", "en_US", "en_ZA", "en_AU", "fr_CH", "fr_FR", "pt_PT", "pt_BR", "es_ES", "es_MX", "zh_CN"]
        precondition(pick(preferred: ["pt-BR"], region: "BR", supported: s) == "pt_BR")
        precondition(pick(preferred: ["fr"], region: "CH", supported: s) == "fr_CH")
        precondition(pick(preferred: ["fr"], region: "BE", supported: s) == "fr_FR")
        precondition(pick(preferred: ["en"], region: "NL", supported: s) == "en_US")
        precondition(pick(preferred: ["en-NL", "nl-NL"], region: "NL", supported: s) == "en_US")
        precondition(pick(preferred: ["nl-NL", "en-GB"], region: "NL", supported: s) == "en_GB") // no Dutch: the next one
        precondition(pick(preferred: ["en-AU"], region: "AU", supported: s) == "en_AU")
        precondition(pick(preferred: ["zh-Hans-CN"], region: "CN", supported: s) == "zh_CN")
        print("language self-test passed")
    }

    static func isEnglish(_ id: String) -> Bool { Locale(identifier: id).language.languageCode == .english }

    /// "Portuguese (Brazil)", in your Mac's language.
    static func name(_ id: String) -> String { Locale.current.localizedString(forIdentifier: id) ?? id }

    /// Every language the recogniser can dictate, by name.
    static func dictatable() async -> [String] {
        await SpeechTranscriber.supportedLocales.map(\.identifier).sorted { name($0) < name($1) }
    }

    /// Already on this Mac, so dictating starts straight away.
    static func installed(_ id: String) async -> Bool {
        await SpeechTranscriber.installedLocales.contains { $0.identifier == id }
    }

    /// macOS's spelling checker's name for it: the exact one ("pt_BR"), else the language alone ("fr"),
    /// else nil when it has no dictionary for it.
    @MainActor
    static func spelling(_ id: String) -> String? {
        let have = NSSpellChecker.shared.availableLanguages
        if have.contains(id) { return id }
        if id == "en_US", have.contains("en") { return "en" }
        let code = Locale(identifier: id).language.languageCode?.identifier ?? id
        return have.contains(code) ? code : have.first { $0.hasPrefix(code + "_") }
    }

    /// Whether Apple's on-device model can tidy text in it.
    static func modelSupports(_ id: String) -> Bool { SystemLanguageModel.default.supportsLocale(Locale(identifier: id)) }
}
