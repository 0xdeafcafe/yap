<h1 align="center">yap</h1>

<p align="center">
  Dictation for macOS. Hold fn, talk, let go, and the text is pasted where your cursor is.<br>
  It runs on the speech model built into macOS, so nothing is sent anywhere and there's nothing to pay for.
</p>

I wrote Yap to replace Wispr Flow, which used 1.3 GB of RAM and around 5% CPU on my Mac whether I was talking or not. Yap uses Apple's `SpeechAnalyzer` and only does any work while you're dictating.

## Accuracy

Wispr Flow keeps your past dictations on disk, audio included. I ran 40 of mine (about 10 minutes) through each engine on an M1 Max.

| Engine | Error rate | Wait after you stop | RAM while working |
| --- | --- | --- | --- |
| Parakeet v3 (MLX) | 7.4% | 0.5 s | 1.1 GB |
| Wispr Flow (cloud) | 7.4% | 0.6 s | 1.3 GB, all the time |
| **Apple SpeechTranscriber (Yap)** | **8.6%** | **0.9 s** | **about 0.1 GB** |
| Whisper large-v3-turbo | 11.1% | 1.4 s | 0.9 GB |

There's no hand-checked transcript for these clips, so each engine is scored against what the other engines agreed on. The numbers are good for comparing engines, not as exact accuracy.

## Cleanup

Wispr Flow passes your words through an LLM to remove filler. I tried Apple's on-device model for the same job. It deleted real words ("I really don't like", "looks terrible") as well as the filler, so Yap doesn't use it. Qwen3 4B kept the words but needed 2.9 GB of RAM and another 1.5 s.

Yap uses rules instead. They remove um and uh, words repeated straight after themselves, and "like", "you know" and "I mean" when they're set off by commas. On the same 40 clips they didn't remove any real words. Grammar is left as you said it.

## Install

```sh
brew tap 0xdeafcafe/yap https://github.com/0xdeafcafe/yap
brew install --cask yap
```

## Build

Needs macOS 26 or newer and Xcode's command line tools.

```sh
./bundle.sh
open Yap.app
```

macOS will ask for two permissions:

- **Microphone**, to hear you. Yap only records while you're dictating.
- **Accessibility**, to see fn from any app and to press ⌘V.

`bundle.sh` signs with a certificate called "Yap Local Signing" if your keychain has one, which keeps the Accessibility permission across rebuilds. Without it the app is signed ad hoc, and macOS asks again after every rebuild.

Quit Wispr Flow first, or both will paste.

`./release.sh` builds `Yap.zip` for a GitHub release and updates the cask's version and checksum. Set `YAP_NOTARY_PROFILE` to a `notarytool` keychain profile to notarise it: macOS won't open an app downloaded through the cask unless it's signed with a Developer ID and notarised.

## Use

| | |
| --- | --- |
| hold `fn` | start listening |
| let go | clean up, paste, and restore your clipboard |
| double-tap `fn` | keep listening without holding the key |
| tap `fn` again | stop, clean up and paste |
| tap `fn` once | nothing (presses under 0.3 s are ignored) |
| `fn` + another key | cancel, so shortcuts like fn+← still work |

Yap takes the fn key over completely, so macOS's own fn actions (the emoji picker, Apple's dictation) no longer happen.

A small glass blob sits on the edge of the screen, faded until you use it. Hovering shows "Hold fn to talk". Holding fn turns it into a dark panel modelled on the Siri in macOS 27, with your words in it as they're recognised. Words Apple is still unsure of are dimmed until it settles on them. A mic orb next to the panel moves further out the louder you speak. When the text is pasted, a "Pasted" chip appears under the panel and everything shrinks back into the blob.

The menu bar icon has:

- **Blob**: dock it on the right, bottom or left edge.
- **Spelling**: British ("organise the colour") or American ("organize the color"). It defaults to British if your Mac's region is the UK.
- **Paste last transcript**, and the five most recent below it: click one to paste it again.
- **Edit words…**: opens `~/.config/yap/words.txt`. Put one name or term per line to help the recogniser spell it. A line like `spoken => written` replaces the phrase after cleanup.

```
LangWatch
Ghostty
btw => by the way
my email address => you@example.com
```

## Logs and recordings

Every dictation adds a line to `~/Library/Logs/Yap/dictations.jsonl` with its timings, the raw and cleaned text, the app it was pasted into and the outcome.

Yap doesn't keep any audio unless you turn it on. If you're working on Yap and want to replay bad transcriptions, set how many hours to keep recordings for:

```sh
defaults write red.forbes.yap audioRetentionHours -float 72   # keep recordings for 3 days
defaults delete red.forbes.yap audioRetentionHours            # stop; what's there goes at the next check
```

Recordings go in `~/Library/Application Support/Yap/audio`. Yap deletes any older than the limit at launch, after every dictation and once an hour. Both folders are readable only by your user.

## Checks

```sh
Yap.app/Contents/MacOS/Yap --selftest      # cleanup rules and recording deletion
Yap.app/Contents/MacOS/Yap --listen 5      # record 5 s from the mic, print raw and cleaned text
Yap.app/Contents/MacOS/Yap --demo bottom   # play the UI on the bottom edge (or right, left)
Yap.app/Contents/MacOS/Yap --keytest       # fake fn taps, double taps and holds (never pastes)
```

## Code

- `Listener.swift`: microphone to `SpeechAnalyzer`, with live results. Recording starts before the analyser is ready so the first word isn't lost. On release it records 200 ms more and appends 0.6 s of silence so the last word isn't dropped.
- `Tidy.swift`: the cleanup rules and the words file.
- `Journal.swift`: the log, the recordings and deleting old ones.
- `Pill.swift`: the blob, panel, orb and chip. They share one `GlassEffectContainer`, which is what makes them merge into and out of each other. The shimmer on unsure words is a gradient driven by a `TimelineView`, and it stops if Reduce Motion is on.
- `FnKey.swift`: an event tap that takes fn away from macOS.
- `App.swift`: taps and holds, pasting, positioning and the menu.
