import AVFoundation
import Speech

/// Mic → Apple's on-device SpeechTranscriber, live. One analyzer per dictation, so the
/// system can drop the model when you're not talking.
final class Listener {
    private let engine = AVAudioEngine()
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzer: SpeechAnalyzer?
    private var results: Task<Void, Never>?
    private var finalText = ""
    private var format: AVAudioFormat?
    private var recording: AVAudioFile?
    /// Seconds of audio heard in the last dictation.
    private(set) var audioSeconds = 0.0

    /// onLevel: 0...1 loudness. onText: (settled words, words still being guessed).
    /// recordTo: where to save what the recogniser hears, or nil to keep nothing.
    func start(locale identifier: String, terms: [String], recordTo: URL? = nil, onLevel: @escaping (Double) -> Void, onText: @escaping (String, String) -> Void) async throws {
        finalText = ""; audioSeconds = 0
        let transcriber = try await Self.transcriber(identifier)
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw NSError(domain: "Yap", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio format for \(identifier)"])
        }

        self.format = format
        if let recordTo {
            recording = try? AVAudioFile(forWriting: recordTo, settings: format.settings,
                                         commonFormat: format.commonFormat, interleaved: format.isInterleaved)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: recordTo.path)
        }
        // Start the mic before the analyzer is ready; the stream buffers, so the first word isn't lost.
        let (stream, cont) = AsyncStream<AnalyzerInput>.makeStream()
        input = cont
        let node = engine.inputNode
        let micFormat = node.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: micFormat, to: format) else {
            throw NSError(domain: "Yap", code: 2, userInfo: [NSLocalizedDescriptionKey: "Can't convert mic audio"])
        }
        node.installTap(onBus: 0, bufferSize: 1024, format: micFormat) { buffer, _ in
            onLevel(Self.loudness(buffer))
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / micFormat.sampleRate) + 32
            guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
            var fed = false
            converter.convert(to: out, error: nil) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true; status.pointee = .haveData; return buffer
            }
            guard out.frameLength > 0 else { return }
            self.audioSeconds += Double(out.frameLength) / format.sampleRate
            try? self.recording?.write(from: out)
            cont.yield(AnalyzerInput(buffer: out))
        }
        engine.prepare()
        try engine.start()

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        if !terms.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = terms
            try? await analyzer.setContext(context)
        }
        results = Task { [weak self] in
            do {
                for try await r in transcriber.results {
                    guard let self else { return }
                    let text = String(r.text.characters)
                    if r.isFinal { self.finalText += text; onText(self.finalText, "") } else { onText(self.finalText, text) }
                }
            } catch {}
        }
        try await analyzer.start(inputSequence: stream)
    }

    /// The same recogniser for live dictation and for benchmarking files, downloaded if it isn't yet.
    private static func transcriber(_ identifier: String) async throws -> SpeechTranscriber {
        // The locale picks the spelling: en_GB writes "colour", en_US writes "color".
        let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: identifier)) ?? Locale(identifier: "en_US")
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [],
                                            reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
        if let install = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await install.downloadAndInstall()
        }
        return transcriber
    }

    /// Transcribes a recording the way live dictation does, for benchmarks: text, and ms until ready and done.
    static func transcribe(_ file: URL, locale: String, terms: [String]) async throws -> (text: String, readyMs: Int, totalMs: Int) {
        let started = Date()
        let transcriber = try await transcriber(locale)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        if !terms.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = terms
            try? await analyzer.setContext(context)
        }
        let ready = Int(Date().timeIntervalSince(started) * 1000)
        let collect = Task { () -> String in
            var s = ""
            for try await r in transcriber.results where r.isFinal { s += String(r.text.characters) }
            return s
        }
        if let last = try await analyzer.analyzeSequence(from: AVAudioFile(forReading: file)) {
            try await analyzer.finalizeAndFinish(through: last)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        let text = try await collect.value.trimmingCharacters(in: .whitespacesAndNewlines)
        return (text, ready, Int(Date().timeIntervalSince(started) * 1000))
    }

    /// Stops the mic and returns everything said, once the last words are settled.
    func stop() async -> String {
        // People let go of the key as the last word ends, so keep listening a moment longer,
        // then add silence so the recogniser commits the final word instead of dropping it.
        try? await Task.sleep(for: .milliseconds(200))
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        recording = nil // closes the file
        if let format, let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate * 0.6)) {
            silence.frameLength = silence.frameCapacity
            for b in UnsafeMutableAudioBufferListPointer(silence.mutableAudioBufferList) { memset(b.mData, 0, Int(b.mDataByteSize)) }
            input?.yield(AnalyzerInput(buffer: silence))
        }
        input?.finish()
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        await results?.value
        analyzer = nil; results = nil; input = nil
        return finalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func loudness(_ b: AVAudioPCMBuffer) -> Double {
        guard let ch = b.floatChannelData?[0], b.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<Int(b.frameLength) { sum += ch[i] * ch[i] }
        let db = 20 * log10(max(sqrt(sum / Float(b.frameLength)), 1e-6))
        return Double(min(max((db + 55) / 40, 0), 1)) // -55 dB silent … -15 dB loud
    }
}
