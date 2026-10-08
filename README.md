<h1 align="center">yap</h1>

<p align="center">
  Hold fn, talk, let go. Your words land wherever your cursor is.<br>
  On-device, free, and a few hundred lines of Swift.
</p>

Yap is a menu bar dictation app for macOS. It started because Wispr Flow was sitting on 1.3 GB of RAM and a few percent of CPU all day, every day, so I could talk to it for a couple of minutes. Apple now ships a perfectly good speech model with macOS, so Yap uses that and gets out of the way the rest of the time.

## How good is it?

Wispr Flow keeps your dictations on disk, audio included. I took 40 of mine at random (about 10 minutes of me rambling at coding agents) and ran them through everything worth trying on an M1 Max.

| Engine | Error rate | Wait after you stop | RAM while working |
| --- | --- | --- | --- |
| Parakeet v3 (MLX) | 7.4% | 0.5 s | 1.1 GB |
| Wispr Flow (cloud) | 7.4% | 0.6 s | 1.3 GB, all day |
| **Apple SpeechTranscriber (Yap)** | **8.6%** | **0.9 s** | **about 0.1 GB** |
| Whisper large-v3-turbo | 11.1% | 1.4 s | 0.9 GB |

There was no hand-checked transcript, so each engine is scored against what the others agreed on. Treat the error rates as close, not gospel. Apple is about a point behind the best, needs no download, and costs nothing.

## Tidying up

Wispr runs your words through an LLM afterwards to drop the "um"s and the "it's not, it's not". I tried Apple's on-device model for the same job. Even after fixing the obvious problems (it refused clips with swearing in, looped on long ones, and happily deleted whole sentences as "filler") it still cut real words like "I really don't like" and "looks terrible". Qwen3 4B did better but wanted 2.9 GB and another second and a half.

So Yap uses rules. They remove ums and uhs, words said twice in a row, and comma-fenced "like", "you know" and "I mean". On the same 40 clips they cut none of my actual words. Grammar stays as you said it.

## Build it

Needs macOS 26 or newer and Xcode's command line tools.

```sh
./bundle.sh
open Yap.app
```

The first time, macOS asks for two things:

- **Microphone**, to hear you. Yap only listens while fn is held.
- **Accessibility**, to see fn from any app and to press ⌘V for you.

`bundle.sh` signs ad hoc, so macOS asks for Accessibility again after every rebuild. Annoying, but expected.

If fn already opens the emoji picker or starts Apple's dictation, set **System Settings › Keyboard › Press 🌐 key to** to *Do Nothing*. Quit Wispr Flow too, or you'll get everything twice.

## Using it

| | |
| --- | --- |
| hold `fn` | listen, with a pill at the bottom of the screen |
| let go | tidy up, paste, and put your clipboard back how it was |
| tap `fn` | nothing, taps under 0.3 s are ignored |

Words still being guessed shimmer in Siri's colours, then settle into plain text once Apple is sure of them. The glow around the pill follows your voice.

**Spelling** is in the menu: British writes "organise the colour", American writes "organize the color". It defaults to British if your Mac's region is the UK.

**Words** (menu › Edit words…) lives at `~/.config/yap/words.txt`. One term per line nudges the recogniser towards your spelling of names and jargon. `spoken => written` swaps a phrase after tidying.

```
LangWatch
Ghostty
btw => by the way
my email address => you@example.com
```

## Checks

```sh
Yap.app/Contents/MacOS/Yap --selftest   # the tidy rules
Yap.app/Contents/MacOS/Yap --listen 5   # five seconds from the mic, raw and tidied
Yap.app/Contents/MacOS/Yap --demo       # the pill, without having to say anything
```

## How it works

- `Listener.swift` streams the mic into Apple's `SpeechAnalyzer` with live results. It starts recording before the analyser is ready, so you don't lose your first word. When you let go it keeps listening for 200 ms and adds 0.6 s of silence, so your last word isn't dropped either.
- `Tidy.swift` holds the rules and the words file.
- `Pill.swift` is the floating Liquid Glass pill and its glow.
- `App.swift` handles fn, pasting and the menu.
