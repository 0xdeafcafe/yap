# yap's site: one dictation, set in columns

The page is a strip of columns you read sideways, the way a long dictation runs on. It opens loud and red with the fn key, and every column after it is a bit of the same speech: the words make room, an instruction sheet, the blob, the numbers on the back of the box, your words, how much it tidies, other apps, and finally the install, red again. The whole page is also a text field. There's a red text cursor in it, and holding space (or the fn key on the page, or the blob on the edge of the window) opens yap's small bubble right under that cursor, plays a sample or listens through your mic, and pastes at the cursor when you let go. Click anywhere in the text to move the cursor and paste there instead. On a phone the strip unfolds downwards in the same order.

It merges four design directions into one system rather than stacking them. Where each piece came from:

| Piece | From | What changed |
| --- | --- | --- |
| The frame: masthead, sideways strip of bordered columns, red fn column, the big `yap` with the teeth biting into it, the column nav with ← → and the progress line, the vertical unfold on phones | astra | Ten columns instead of seven. Arrow keys now step columns. The recording column was cut (the recording shows the old teeth orb). |
| Type as speech: "i was going" at 72, then 40, then 24 as the sentence grows; grey guesses that settle to ink; "reddis" turning into Redis with a peach mark; fillers struck through then dropping out of the line | sonnet | Lives inside columns now, and triggers when a column is mostly on screen, not on vertical scroll. Cleanup examples (`um, the the`, `john, no wait,`) stay struck so you can read the rule; fillers in prose drop away. Sonnet's pinned teeth panel was cut: the real panel replaces it. |
| Instruction-sheet parts: hold fn / talk / let go drawings, the spec plate with its title row and inverted yap row, "the small print, at a readable size", the pushbutton with a solid offset shadow | sol | The drawings were redrawn for the current app (the bubble under the caret with its red light, the text on the line and the bubble gone, the blob back on the edge). The plate prints in ink on astra's red instead of white on sol's darker red. Sol's rounded display face, wind-up chatter and carton border were cut so the page keeps one type system and one motion language. |
| The cursor and the panel: red text cursor placed by clicking, hold space for fn, the scripted dictation per column, Web Speech behind "use my mic", the rules (fillers, repeats, `btw`, near misses of words on the page), the live.sock lines, ⌘-drag the blob, ⌘Z | opus | Ported, then updated to the app as it is now (below). |

## The app as it is now

Everything about the panel is read from the Swift sources, not the old screenshots or promo video (both show the teeth orb, so neither is used). The app changed while this was being built. The caret bubble is commit `5fce47e` (`Caret.swift`, `Pill.swift`, `App.swift`). A later commit had the words fly from the bubble onto the line with a band of light over them (`2d1deaa`); it was reverted (`48b2499`), so the page doesn't do it either.

- **At the caret it's a small bubble** (`Caret.Bubble`). Sized from the line the cursor is on: 13 to 15 px type (`round(line / 1.25) + 1`), a line of `ceil(font × 1.2)`, 7 px padding, round ends. It starts as a dot one line high, then hugs the words up to 400 wide (the screen less 16 on a phone), then wraps to three lines with the oldest fading off the top. It sits 6 to 14 px under the line (`0.4 ×` line height), left-aligned so its cap is under the cursor, and opens above the line when there's less room below than its tallest and more above. Size spring .3/.9. No orb, chip or app name at the caret.
- **The light**: `Pulse` at .62 scale, tinted the system red (`#ff3b30`, `#ff453a` in dark), in the bubble's leading cap, while listening and finishing.
- **The glass follows the system appearance**: light glass with black text and a black hairline at .12 in light mode, dark glass with white text and a white hairline at .2 in dark; the moving light at .55. Fixes are underlined in the mark colour, a darker orange (`rgb(.78,.38,.02)` → `#c76105`) in light mode so it holds on white, peach in dark.
- **Letting go**: the bubble gets out of the way of the words as they land: it fades over 120 ms, the text is pasted at the cursor with no highlight (fixes keep their mark), and after 150 ms the blob fades back in on its edge over 250 ms, with no shrinking first.
- **The edge blob** is the idle affordance (12 × 44 on a side, 44 × 12 on the bottom, hover 184 × 40 with "Click or hold to talk", ⌘ shows "Drag to move"), and the fallback: with no cursor on screen the dark panel opens out of it (496 wide, `Pulse` orb on its right, "Pasted" chip, the app's 22/18/15 type). The page moves the cursor into the column you're reading first, so in practice you'll see the bubble; the copy says most terminals don't report a cursor, which is when the app uses the blob.
- **The orb is `Pulse`**: a dot (10 + 3 × level) inside a 1.5 px ring (14 + 14 × level, at .12 + .45 × level), spring .35/.9. With reduce motion nothing changes size (ring 22, dot 11) and the ring brightens instead. The teeth are only the logo now.
- **Cleanup has three levels**: light (only the rules), medium (default, Apple's on-device model fixes punctuation and grammar a sentence at a time, and yap pastes its own sentence if a word goes missing), heavy (also drops what you take back and makes bullets). Medium and heavy need Apple Intelligence. The page only does light, and says so.

## Colour

| Token | Light | Dark | Why |
| --- | --- | --- | --- |
| `--paper` | `#ffffff` | `#24211e` | A blank document to type into (opus, astra). Not cream: that's the tasteful-AI default, and the dark glass reads best over white. Dark is a warm charcoal from astra. |
| `--ink` | `#171513` | `#f6ead4` | Warm near-black (astra). In dark it's the teeth's enamel cream. |
| `--muted` | `#625b56` | `#bcb2a7` | Brown-grey for notes and for guesses that haven't settled. 6.7:1 on white, 7.7:1 on the dark ground. |
| `--rule` | `#c9c2bc` | `#5d554e` | Hairlines between rows. Column borders use ink. |
| `--red` | `#f3452b` | same | Astra's gum red, flat and broad: the fn column, the spec plate, the install column, and the text cursor. Text on it is always ink (4.9:1); never white (3.7:1). |
| `--on-red` | `#171513` | same | Ink on red, both schemes. |
| `--peach` | `#ffd9a8` | same | The app's fix colour (`Said.fixColor`). It means "yap did this": fixed words, the paste highlight, the words it would read off this window while you talk. |
| `--code` | `#f4f1ee` | `#2f2b27` | Files and socket lines, so they read as things a program wrote. |
| `--enamel` | `#f6ead4` | same | Text on ink: the pressed fn key and the yap row of the plate. |
| bubble glass | `rgba(255,255,255,.62 → .5)`, blur 14, black text | `rgba(20,18,16,.6 → .5)`, white text | The caret bubble's light and dark glass, a little more opaque than the app's so text holds over a page that isn't a real window behind. Reduce transparency: `#f7f7f7` / `#292929`. |
| `#c76105` | fix mark, light | peach | The app's light-mode mark colour, for fixes in the bubble. |
| `#ff3b30` | the light | `#ff453a` | System red, the recording light only. |
| edge glass | `rgba(26,20,17,.86 → .74)`, blur 18, saturate 1.5 | `rgba(6,5,4,.78 → .6)` | The blob and the fallback panel: the app's smoke gradient, darkened so white text holds on a white page. Reduce transparency: solid `#1c1c1c`. |

No page gradients, glows or textures. The only gradients are inside the supplied teeth artwork, the glass, the travelling edge light, and the band sweeping through guessed words, all from the app.

## Type

- **Page: Helvetica Neue** (then Helvetica, Arial). From astra: yap is a Mac app, and Helvetica Neue is Mac typography from before the current run of SaaS faces. Its tight lowercase lets size do the work. No web font to load or license.
- **Panel: the system UI font** (SF on a Mac). The one exception, because the app draws the panel in SF and the panel should look like the app.
- **Mono: ui-monospace, Menlo** only for things a terminal or program reads: the brew line, `words.txt`, the socket JSON, paths.
- **Scale:** 16 (notes), 18 (body, 1.55), 24 (lead, h3), 40, 56, 72, plus the 184 wordmark. Tracking tightens only from 40 up. Weights 400, 500, 700. The bubble uses 13 to 15 from the line it's on; the fallback panel keeps the app's own 22/18/15 (4, 5 and 6 lines), 15 hint, 13 chip, 12 target.
- **Shrinking:** the talk column's sentence goes 72 → 40 → 24 as it gets longer, which is what the fallback panel does at 22 → 18 → 15. Headings across the strip vary between 40, 56 and 72 by how much they carry, so the columns don't all weigh the same.
- **Case:** lowercase, because the README is lowercase and that's Alex's voice. Proper nouns that the word learner cares about keep their capitals (Redis, LangWatch, SpeechTranscriber). The app's own strings keep the app's case ("Click or hold to talk", "Pasted").

## Shape

- **Radii:** 0 on the layout (columns are pages divided by rules, not cards); 6 for small controls, kbd, the plate and code; 16 for the fn key (a Mac key, scaled up); the panel's own 26 / 20 / 10 / round from Pill.swift; the bubble is fully round-ended.
- **One shadow rule:** the pushbutton (sol). A solid offset in the button's own ink colour, 3 px (4 on the fn key), pressing to 1 px as it moves down 2–3 px. No blurred shadows anywhere on the page.
- **Spacing:** an 8 px unit (8, 16, 24, 32, 40). Columns 32 px inset (24 on phones). Column widths follow their content: 400 fn, 560 talk, 480 sheet, 500 blob, 520 numbers, 680 plate, 560 words, 500 tidy, 600 other apps, 560 install.
- **Drawings:** 1.5 px ink line art with red for what moves (the press arrow, the caret) and peach for what was pasted, drawn for this page.

## Motion

Three kinds, and nothing else moves on its own:

1. **The panel's springs**, ported as a real damped spring in JS: phase .52/.86, bubble size .3/.9, hover .48/.86, level .28/.86, pulse .35/.9, drip .65/.86, text height .24/1, drop after a drag .38/.65; the edge light goes round once every 6 s while it's open; guessed words have a light band every 1.6 s. The loop only runs while something moves.
2. **Settling** (sonnet), when a column is mostly on screen: guesses go grey → ink over 400 ms; "reddis" swaps to Redis and gets its peach underline; a filler's strike draws over 300 ms and, 900 ms later, it collapses out of the line over 400 ms. At the fallback panel, pasted text holds a peach highlight that fades over 1.4 s so you can see where it went; at the caret it's just there, as in the app.
3. **Press:** buttons move down over 120 ms.

The text cursor blinks on a 1.06 s step (a Mac caret's rhythm) and holds still while you talk. The sample dictation types a word every length × 45 + 160 ms (App.swift's `--demo` pace) and waits 0.9 s after you let go, which is the benchmark's wait.

Scrolling is native: no wheel hijacking, no snapping. Desktop moves sideways with a trackpad, shift-wheel, the scrollbar, ← → keys, the column nav and the buttons. **Reduced motion:** springs jump, the bubble doesn't grow (it fades in over 150 ms)  the pulse holds its size and brightens instead, no edge light, sweeps or blink, fillers stay struck rather than dropping, smooth scrolling is off, and the finishing wait is 300 ms.

## Keys and access

- Space stands in for fn: hold to talk, let go to paste; a quick tap waits 350 ms for a second tap (hands free, tap again to paste); space plus any other key cancels (so space + ← doesn't move the strip); esc cancels; ⌘Z takes back the last paste. A button or link you've tabbed to keeps its own space bar.
- The fn key on the page: hold with a pointer, or Enter (or a screen reader's activation) for hands free, Enter again to paste. It shows pressed while listening.
- The blob is a real button (focusable, Enter for hands free). A polite live region says "playing the sample", "pasted: …" and "cancelled".
- Focus is a 3 px ink outline everywhere, ink on red too.

## Delivery

Plain HTML, CSS and two scripts, no build, no network; opens from `file://`. `strip.js` is the frame (columns, settling, copy); `yap.js` is the panel and the cursor. Assets: `teeth.svg` (the supplied vector teeth, 14 KB), `favicon.png` (64 px) and `apple-touch-icon.png` (180 px) resized from `icon/icon-1024.png`, and `social.png`, a 1200 × 630 card rendered from the page's own CSS (the promo card is cream and shows only half the install). No `demo.webp` or video: they show the old orb. Open Graph image paths are relative and need the production origin when it's deployed.
