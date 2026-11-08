# opus concept: the page you dictate into

## The idea

The page is a plain document with a red insertion point in it, and yap's blob sits on the edge of the browser window the way it sits on the edge of your screen. Hold space (it stands in for fn, which browsers can't see), or press the blob, and it opens into the real listening panel: the teeth chatter with how loud you are, the newest words shimmer while it's still guessing, then you let go, it waits 0.9 s (yap's own number from the benchmark table), drips a "Pasted" chip and puts the words wherever the cursor is. Click anywhere in the text and the cursor goes there, so you can paste into the headline, the table or the words.txt file if you like. Without the mic it plays one of Alex's dictations, written per section, and each hold carries on from where the last paste stopped, so how long you hold is how much gets said. The features are shown by the paste rather than described: in "it learns your words" the dictation says "um the reddis cache basically falls over when lang watch is busy, btw", the page's words light up while you talk (the words yap would read off this window), and it pastes "So the Redis cache falls over when LangWatch is busy, by the way." with a note saying what it heard and dropped. The live.sock section shows the actual JSON lines this page would send while you talk, with the browser's bundle id as `app`. Everything is readable without touching it; the toy is on top.

Reference first: `Sources/Yap/Pill.swift`, `Teeth.swift` and `App.swift` (the `--demo` routine), not a mockup. The blob is a port, not a lookalike.

## The blob, ported from the app

| Thing | Value | From |
| --- | --- | --- |
| Resting size | 12 × 44, radius 6 on a side edge; 44 × 12 on the bottom | `LiquidOutline` widths/heights |
| Hover | 184 × 40, radius 20, "Click or hold to talk" at 15px; "Drag to move" with ⌘ | Pill.swift |
| Open | 496 wide (narrower on phones), height = text + 44, radius 26, text 440 wide, padding 28/22 | Pill.swift |
| Mic orb | 38 px circle, teeth 22 px, gap 1 + 10 × level, joined by the `circleBridge` curve | Pill.swift |
| Teeth | Teeth.swift's rects in a 36 × 36 box, jaw rotated 8° + 26° × level about (27, 21.5) | Teeth.swift |
| Pasted chip | 98 × 30, drips 24 px away 300 ms after done, bottom-edge panel lifts 54 | Pill.swift |
| Text fit | 22px for 4 lines under 140 chars, 18px/5 under 225, then 15px/6, oldest words go off the top | `fit`, `Said.latest` |
| Guessing words | white at .5, with a light band sweeping through every 1.6 s | `Said` |
| Caret in panel | 2px bar, opacity .6 + .4 × level, then "— let go to paste" at .5 | `Said` |
| Springs | phase .52/.86, hover .48/.86, level .28/.86, drip .65/.86, drop after a drag .38/.65 | the `.animation` modifiers; a real damped spring in JS, not CSS easing |
| Edge light | 1.6px hairline at .3 white, plus a conic highlight going round once every 6 s while open | `GlassSurface` |
| Timing | words every length × 45 + 160 ms, three still guessing; tap ≤ 300 ms waits 350 ms for a double tap; hold on the blob starts after 300 ms; hides 900 ms after pasting | App.swift |
| Union | main body, orb, chip and bridges as one path, each subpath forced clockwise so overlaps union under nonzero; the glass is a `clip-path: path()`, the hairline is stroked on a canvas then the inside cut away, so internal seams never show | `LiquidOutline.path` |

Keys behave like the app: hold to talk, double-tap for hands free, tap again to paste, space plus another key cancels, esc cancels. ⌘-drag moves the blob to another edge and remembers it. ⌘Z takes back the last paste. On phones and narrow windows it lives on the bottom edge.

The animation loop only runs while something moves; at rest the page does nothing, like the app.

## Tokens

| Token | Light | Dark | Why |
| --- | --- | --- | --- |
| Paper | `#ffffff` | `#161210` | A blank document. White, not cream, so the page isn't the cream-and-terracotta default and the dark glass reads as something sitting on top of your work. Dark is a warm near-black, following the system. |
| Ink | `#1d1916` | `#f1e9df` | Warm near-black from the launch video's `#0c0a09`, lifted a touch for body text. |
| Muted | `#655c54` | `#ab9f93` | Same warm family, ≥ 5.5:1 on paper in both. Used for notes and the small print only. |
| Rule | `#e6dfd7` | `#3b332d` | Table and key rows. |
| Red | `#e5371f` | `#ff5a3e` | The teeth's red. It's used for the insertion point, yap's one square in the memory chart, link underlines and focus rings, never for text on paper, because at 4:1 it isn't legible small. |
| Red ink | `#b42510` | `#ff8a70` | Link hover text, where red has to be legible. |
| Peach | `#ffd9a8` | warm 32% | The launch video's peach. Marks what you just pasted (fading to an underline) and the words yap would read while you talk. |
| Code ground | `#f6f2ed` | `#211b18` | The command lines and files, so they read as things to copy. |
| Glass | warm smoke `rgba(26,20,17,.86 → .74)`, blur 18, saturate 1.5 | `rgba(6,5,4,.72 → .52)` | The app's smoke gradient plus tint, darkened on white paper so settled white text stays well above 4.5:1 (the dim guessing words are dimmer on purpose, as in the app). Reduce transparency makes it solid `#1c1c1c`, as in the app. |

## Type

- **Sans: the system stack, SF Pro on a mac.** A deliberate choice: yap only runs on macOS 26, the panel in the app is drawn in SF, and the page is pretending to be a document on your mac. Shipping a web font would make the panel look less like the real thing. Non-mac visitors get Segoe or their system sans, which is fine for a page about a mac app.
- **Mono: ui-monospace, SF Mono.** Only for things you type or that a program writes: the brew lines, words.txt, the socket JSON, file paths.
- **Scale:** 16, 19 (body), 24 (lede, headings), 40 (the two memory numbers), and the headline at up to 112 (52 on a phone). The panel keeps the app's own 22/18/15 and 13 for the chip, as a product exception.
- **Weights:** 400 and 600 only.
- **Leading:** body 1.6, lede 1.45, headline 1.0 with −0.035em tracking (the only tracked size), panel 1.22.
- **Case:** lowercase, because the README and the brief are lowercase. The app's own strings ("Click or hold to talk", "Pasted") keep their sentence case, as the app writes them.

## Layout

One left-aligned column, 36rem, starting about 11vw in; the right side of the window is left open because that's where the blob lives. Things that need room break the measure: the headline, the memory chart and the benchmark table. Section gaps vary (112 to 176 px) so the memory chart and the end get more air. No cards, no nav beyond the name and a source link.

## Radius, shadow

- 6 px: code blocks, buttons, kbd (the app's resting blob radius).
- 26 / 20 / round: only the blob, from the app.
- No shadows on the page. The only depth is the glass's own blur.

## Motion

Three kinds, all from the app: the blob's springs, the caret blink (steps, 1.06 s, stopped while you talk, as a mac caret holds still while typing), and the paste highlight fading to an underline over 1.4 s. The context words fade in and out over 200 ms. `prefers-reduced-motion` turns all springs into jumps, holds the jaw half open, fixes the orb gap at 4 and the chip gap at 24 (as `reduceMotion` does in Pill.swift), stops the edge light, the sweep and the blink, and shortens the finishing wait.
