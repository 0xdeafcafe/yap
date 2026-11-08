import AVFoundation
import ApplicationServices
import SwiftUI

/// The first time Yap opens: what it needs from macOS, Apple Intelligence for cleanup, and the few choices that
/// matter, a page at a time on glass. Open it again from the menu with Set Up Yap….
struct Onboarding: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @AppStorage("onboarded") private var onboarded = false
    @AppStorage("locale") private var locale = Dictation.defaultLocale
    @AppStorage("formatting") private var formatting = false
    @AppStorage("cleanup") private var cleanup = Cleanup.current.rawValue
    @State private var step = Step.welcome
    @State private var microphone = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var accessibility = AXIsProcessTrusted()
    @State private var model = Polish.unavailable
    @State private var languages: [String] = []
    @Namespace private var glass

    @State private var tried = ""
    @FocusState private var tryFocused: Bool

    enum Step: Int, CaseIterable { case welcome, permissions, intelligence, choices, tryIt }

    var body: some View {
        VStack(spacing: 0) {
            GlassEffectContainer(spacing: 16) {
                Group {
                    switch step {
                    case .welcome: welcome
                    case .permissions: permissions
                    case .intelligence: intelligence
                    case .choices: choices
                    case .tryIt: tryIt
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(28)
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
                .glassEffectID("card", in: glass)
                .id(step)
                .transition(.blurReplace)
            }
            .padding([.horizontal, .top], 20)
            footer.padding(20)
        }
        .frame(width: 560, height: 520)
        .animation(.smooth(duration: 0.35), value: step)
        .task {
            // Each can change while you're on another app turning it on.
            while !Task.isCancelled {
                microphone = AVCaptureDevice.authorizationStatus(for: .audio)
                accessibility = AXIsProcessTrusted()
                model = Polish.unavailable
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .task { languages = await Language.dictatable() }
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            Text("Welcome to Yap").font(.largeTitle.bold())
            Text("Hold fn and talk. Let go, and what you said is pasted wherever you're typing.")
                .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("Everything happens on this Mac. Nothing you say leaves it.")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var permissions: some View {
        page("What Yap needs", "Two things from macOS, both kept on this Mac.") {
            row("mic.fill", "Microphone", "To hear you while you hold fn.", done: microphone == .authorized) {
                if microphone == .notDetermined {
                    AVCaptureDevice.requestAccess(for: .audio) { _ in }
                } else {
                    open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
                }
            }
            row("accessibility", "Accessibility", "To notice fn in any app, and to paste for you.", done: accessibility) {
                AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
                open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            }
        }
    }

    private var intelligence: some View {
        page("Apple Intelligence", "Yap uses Apple's on-device model to fix punctuation and grammar as you talk, drop what you take back, and make lists.") {
            if let missing = model {
                let turnOn: (() -> Void)? = missing.canTurnOn ? { Polish.openAppleIntelligenceSettings() } : nil
                row("apple.intelligence", "Not ready yet", missing.reason, done: false, action: turnOn)
                Text("You can carry on without it: Yap still takes out um and uh. It starts using Apple Intelligence as soon as it's ready.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                row("apple.intelligence", "Ready", "Apple Intelligence is on, and runs entirely on this Mac.", done: true, action: nil)
            }
        }
    }

    private var choices: some View {
        let level = Cleanup(rawValue: cleanup) ?? .medium
        return page("How you like it", "You can change any of this later in Settings.") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Language", selection: $locale) {
                    ForEach(languages.contains(locale) ? languages : [locale] + languages, id: \.self) { Text(Language.name($0)).tag($0) }
                }
                Text("Yap downloads it the first time you dictate, if it isn't on this Mac yet.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Picker("Cleanup", selection: $cleanup) {
                    ForEach(Cleanup.allCases, id: \.rawValue) { Text($0.rawValue.capitalized).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                Text(GeneralPane.describe(level, polishable: Polish.available && Language.modelSupports(locale),
                                          english: Language.isEnglish(locale), language: Language.name(locale)))
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Toggle(isOn: $formatting) {
                Text("Formatting")
                Text("Say “new line”, “bullet”, or “code npm test end code”.").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    /// Have a go before you leave: it's the one thing that shows it all works, permissions and all.
    private var tryIt: some View {
        let ready = microphone == .authorized && accessibility
        return page("Have a go", ready ? "Hold fn, say something, and let go. It lands in the box below."
                                       : "Yap needs the microphone and Accessibility first. Go back a page to turn them on.") {
            TextEditor(text: $tried)
                .font(.title3)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 120)
                .background(.background.opacity(0.4), in: .rect(cornerRadius: 14))
                .focused($tryFocused)
                .disabled(!ready)
                .onAppear { tryFocused = ready }
            if !tried.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label("That's it. It works the same in any app.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).transition(.opacity)
            } else if ready {
                Text("Double-tap fn to talk hands free, and tap it again to paste. Esc cancels.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .animation(.smooth, value: tried.isEmpty)
    }

    // MARK: Pieces

    private var footer: some View {
        HStack {
            if step != .welcome {
                Button("Back") { step = Step(rawValue: step.rawValue - 1)! }
                    .buttonStyle(.glass).controlSize(.large)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { s in
                    Capsule().fill(s == step ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                        .frame(width: s == step ? 18 : 6, height: 6)
                }
            }
            Spacer()
            Button(step == .tryIt ? "Start Yapping" : "Continue") {
                if let next = Step(rawValue: step.rawValue + 1) { step = next } else { onboarded = true; dismissWindow() }
            }
            .buttonStyle(.glassProminent).controlSize(.large).keyboardShortcut(.defaultAction)
        }
    }

    private func page<Content: View>(_ title: String, _ subtitle: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.title.bold())
                Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ symbol: String, _ title: String, _ detail: String, done: Bool, action: (() -> Void)?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).frame(width: 32).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.green).transition(.scale.combined(with: .opacity))
            } else if let action {
                Button("Turn On", action: action).buttonStyle(.glass)
            }
        }
        .padding(14)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
        .animation(.smooth, value: done)
    }

    private func open(_ url: String) {
        if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    }
}
