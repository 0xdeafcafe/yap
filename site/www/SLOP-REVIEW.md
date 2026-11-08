# yap's site against rush's ANTI-SLOP.md

Checked against `rush/site/ANTI-SLOP.md` (the 2026-11-07 version). For each section: what passes, what bends the rule and why, and what was fixed on the way. Where the list says "rush", read "yap".

## Type
- **Passes.** Helvetica Neue, a deliberate choice (DESIGN.md, Type), not Inter or a "tasteful free" face. No web font is declared, so none can silently fail to load. No serif, no italic accent word, no eyebrows, no mono labels as chrome, no mono headline. Weights 400/500/700, nothing light. Body 18/1.55, notes 16. Prose columns are 500 to 560 wide, about 60ch. No gradient text in the copy, no Title Case, no `//` or `·` separators.
- **Bends: lowercase.** Headings, nav and buttons are lowercase. The checklist allows it when the brand voice really is lowercase, and yap's README is lowercase throughout. Proper nouns keep their capitals and the app's own strings keep the app's case ("Click or hold to talk", "Pasted").
- **Bends: the scale.** On desktop the page uses 16, 18, 24, 40, 56 and 72, plus the 184 wordmark: seven sizes against "5 or 6". The responsive steps add 32 to 52 and 148, and the panel adds the app's own 12, 13 and 15 (plus 22/18/15 in the fallback panel). The extra page sizes come from the talk column's 72 → 40 → 24 shrink, which is the point of that column.
- **Bends: em dashes.** None in the copy. The fallback panel shows "— let go to paste" while you talk, because that's how the ported panel read; it's gone from the caret bubble, which the app doesn't caption.

## Colour
- **Passes.** One dominant colour (astra's gum red, flat), one accent (peach, which only ever means "yap did this") and a warm neutral ink, on white, not cream. No purple or blue, no glows, no blooms, no neon on near-black. Dark mode follows the system, with a real light design first. Greys are warm and picked from the palette. Contrast: ink on red 4.9:1, muted on white 6.7:1, muted on the dark ground 7.7:1. White on red (3.7:1) is never used.
- **Bends: the grey guessed words.** The talk column and the panel show words still being guessed at reduced contrast, because that's what the app does. Once they settle they're full ink, and the settled state is what screen readers get.

## Layout and components
- **Passes.** No hero pill, no centred hero with two buttons, no logo strip, no stats row, no feature cards, no icon tiles, no emoji, no check-mark lists, no testimonials, no pricing, no FAQ, no fake window chrome, no texture. The order follows the dictation: fn, talking, how to hold it, where it lives, ram, the benchmark, words, cleanup, other apps, install. Columns are pages divided by rules, not cards. Widths differ by content (400 to 680), and the red columns plainly outweigh the white ones.
- **Bends: glass and backdrop-filter.** Six `backdrop-filter` hits, all on the panel (the bubble's light and dark glass and the edge panel's smoke) and their reduce-transparency overrides. It's a port of the app's own glass, not a sticky-nav finish. The page chrome has none.
- **Bends: a blinking red cursor.** The checklist bans "a pulsing or blinking status dot in a corner". This is a text cursor in the text, and it's the interface: you click to move it and the dictation pastes there. It holds still while you talk and doesn't blink at all with reduce motion. The pulsing red light in the bubble is the app's recording light, shown only while you're talking.
- **Bends: three unnumbered steps.** "hold fn / talk / let go" is three things, which the list is wary of. They're the README's own three verbs and the actual product, drawn as an instruction sheet (sol), without 01/02/03.
- **Bends: kbd chips.** `fn`, `space` and `esc` are shown as keycaps, but each is a real yap key, shown in the sentence that says what it does.
- **Bends: duplicate links.** The masthead's three links (the numbers, source, install yap) also appear in the column nav. They're short, and on phones the column nav is hidden, so there's only one set.
- **Checked:** focus is a 3 px outline everywhere (ink on red too); the title, description and favicon are real; 404.html has its own title and description. Nothing overflows at 1440 × 900, 1280 × 800, 1920 × 1080, 768 × 1024 or 390 wide (scrollWidth 390). At 1280 × 800 the page scrolls 20 px vertically on purpose, with the column nav sticky.

## Dev-tool pages
- **Passes.** No terminal mockup. The install line is the real one-line cask install (`brew install --cask 0xdeafcafe/tap/yap`), with a plain copy button and a fallback that selects them. No badges or stars. The headline says what it does ("your voice, where your cursor is."). Real files and names are used: `~/.config/yap/words.txt`, `live.sock` and its real fields, SpeechTranscriber, settings › general › cleanup. The benchmark table is the README's, with its caveat kept beside it.
- **Bends: the sample dictation.** Without a mic the page plays sentences I wrote. They're labelled as a sample in the copy ("without your mic it plays a sample i wrote") and in the text itself. The socket lines are what this page would write, generated live, not invented output.
- **Bends: "nothing leaves your mac".** The checklist is wary of privacy reassurance. This one is the README's own claim and central to the product, and the page also says where it isn't true: with "use my mic" your browser does the listening, and Chrome sends that audio to Google.

## Motion
- **Passes.** No fade-up reveals, hover lifts, count-ups, parallax, carousels or scroll-jacking. Native scroll sideways and down. Three kinds of motion, each meaning something (DESIGN.md, Motion): the panel's springs, words settling, and the press. Reduced motion is honoured throughout and was tested.
- **Bends: settling on view.** Words in a column settle (grey to ink, "reddis" to Redis, fillers struck) when the column comes into view. That's a scroll-triggered reveal, but it's a handful of words per column showing what yap does to them, not whole sections sliding in.
- **Bends: springs.** The panel uses real springs with the app's response and damping values.
- **Bends: durations.** The strike-then-collapse of a filler takes about 1.3 s and the peach on a fallback paste fades over 1.4 s, past the "about 500 ms" guide. Neither blocks anything; both are the thing being shown.

## Copy
- **Passes.** Facts come only from the README. No SaaS verbs, no "No X. No Y.", no "not X, it's Y", no question-then-answer, no aphorisms, no slogan per section, no bold-labelled bullets. Alex's voice: short, uneven, dry ("i wanted my ram back.", "give your keyboard a minute.").
- **Fixed.** "made by alex, mostly by talking" was cut: it was invented.
- **Watch.** "there's no app to switch to and no window" in the blob column is inferred from the README (a menu bar app with a blob), not quoted from it.

## Craft
- **Passes.** It came from the four reviewed concepts, merged, and each piece is traced in DESIGN.md. Every token is recorded with a reason. Screenshot-and-compare at 1440, 768 and 390, light and dark, normal and reduced motion. Hand-set things a template wouldn't do: the teeth biting into the wordmark, the drawn instruction sheet, "for oh for → 404" on the 404 page, the plate's inverted yap row. Favicon, touch icon, social card and 404 are done.
- **Scanner pass:** `backdrop-filter` ×6 and `background-clip` ×6, all in the panel (the glass, and the light band through guessed words in each of the panel's modes). No `rounded-2xl`, `shadow-lg`, `indigo`, `violet`, `data-aos`, `whileHover` or `lucide`.

## Fixed during the build
- A double red line at the cursor's field (border plus cursor) became a single bottom rule.
- Columns overflowing at 1440 × 900 and 1280 × 800: copy tightened and a short-viewport size added; the instruction sheet's copy was cut again when its drawings changed for the bubble.
- An orphaned "this." in the talk column: balanced wrapping.
- The cleanup examples vanished when their fillers collapsed; they now stay struck so the rule is readable.
- At 768 the talk column was cut off: tablet sizes added.
- The phone plate read "1.3 gb, all the time of ram": now a "ram" prefix.
- A 1 px horizontal overflow from the live region.
- Space released on a focused fn key fired a click that pasted early.
- The 404's teeth sat too far from the wordmark.
- The panel was redrawn twice while this was built, because the app changed: first the dot at the caret growing into the panel, then the small bubble. A flight of the words onto the line was built from a commit that was then reverted, and taken out again. DESIGN.md says which commits the page follows.
