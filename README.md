<p align="center">
  <img src="icon/icon-1024.png" width="180" alt="yap's icon: a set of cream wind-up chattering teeth">
</p>

<h1 align="center">yap</h1>

<p align="center">
  dictation for macos. hold fn, talk, let go, and it's pasted wherever your cursor is.<br>
  it uses the speech model that comes with macos, so nothing leaves your mac and it's free.
</p>

<p align="center">
  <img src="screenshots/demo.webp" width="600" alt="yap's blob opening into the listening panel, words appearing and shrinking as they pile up, then pasting">
</p>

i wrote it to replace wispr flow, which sat on 1.3 gb of ram and about 5% cpu whether i was talking or not. yap sits on about 0.1 gb and only does anything while you're talking.

## install

```sh
brew tap 0xdeafcafe/yap https://github.com/0xdeafcafe/yap
brew install --cask yap
```

it'll want the microphone (to hear you) and accessibility (to see fn and press ⌘V). quit wispr flow first, or both will paste.

## use

| | |
| --- | --- |
| hold `fn` | talk, let go to paste |
| double-tap `fn` | hands free, tap again to paste |
| `fn` + another key | cancel, so fn+← still works |
| `esc` | cancel |

or click the blob to start and click it again to paste. hold ⌘ and drag it to move it to another edge.

yap takes fn over while it's running, so the emoji picker and apple's dictation don't open. your setting comes back when you quit.

the menu bar icon has your history, british or american spelling, a few app icons, and opt-in formatting ("new line", "bullet", "code npm test end code"). it also learns your words: fix a name it got wrong after it pastes and it'll spell it right next time. you can add your own to `~/.config/yap/words.txt` too, one per line, or `btw => by the way` to swap a phrase.

## is it any good

i ran 40 of my old wispr flow dictations (about 10 minutes) through each engine on an m1 max.

| engine | error rate | wait after you stop | ram |
| --- | --- | --- | --- |
| parakeet v3 (mlx) | 7.4% | 0.5 s | 1.1 gb |
| wispr flow (cloud) | 7.4% | 0.6 s | 1.3 gb, all the time |
| **apple speechtranscriber (yap)** | **8.6%** | **0.9 s** | **0.1 gb** |
| whisper large-v3-turbo | 11.1% | 1.4 s | 0.9 gb |

nobody hand-checked these, so each one's scored against what the others agreed on, which is fine for comparing them but isn't an exact accuracy.

wispr flow cleans up filler with an llm. apple's on-device model deleted real words when i tried it ("i really don't like", "looks terrible"), and qwen3 4b wanted 2.9 gb and another 1.5 s, so yap uses plain rules: um, uh, repeated words, and a comma'd "like" or "you know". none of them took out a real word on the same 40 clips.

## build

needs macos 26 and xcode's command line tools.

```sh
./bundle.sh && open Yap.app
Yap.app/Contents/MacOS/Yap --selftest     # the rules and the tests
Yap.app/Contents/MacOS/Yap --demo bottom  # play the panel on the bottom edge
```

every dictation is logged to `~/Library/Logs/Yap/dictations.jsonl`. audio's only kept if you ask (`defaults write red.forbes.yap audioRetentionHours -float 72`).

releasing: bump the versions in `Info.plist`, run `./release.sh` with `YAP_NOTARY_PROFILE` set, and put `Yap.zip` and `appcast.xml` on a github release called `v<version>`.

it leans on two private apis, one to stop fn opening the emoji picker and one for the hand cursor. both need replacing before it could go on the app store.
