# yap, concept "sonnet": the page is the dictation

The whole page reads as one long dictation. It opens loud, like the first word you say, and each later thought opens one step smaller, the way yap's listening panel drops text from 22 to 18 to 15 pt as it fills. Body paragraphs start as grey guesses and settle to ink as they scroll into the top of the screen. A few words are real guesses: "tock" firms up into "talk", "reddis" into "Redis", with a peach marker that fades. Fillers ("um", "basically") are struck in red-grey, then drop out of the line. At the bottom the pinned panel flips from "let go to paste" to "pasted" and the install block flashes once: that is the paste. A live Web Speech demo (only shown where the browser has it) shows interim words grey and final words ink, with um/uh struck.

## Type
- System stack: `-apple-system, "SF Pro Display", "Helvetica Neue", Helvetica, Arial`. Chosen on purpose: yap is mac-only and its panel is set in the system font, so the page is too. No font file to ship or license. On non-Apple machines it falls back to Helvetica/Arial.
- Mono `"SF Mono", Menlo`: only for the install commands, file paths and the json line, as real code.
- Five sizes (the speech steps): s1 clamp(60,15vw,248) weight 800, s2 clamp(40,8.5vw,136) 800, s3 clamp(32,5.2vw,84) 700, s4 clamp(22,2.9vw,44) 500, s5 18px/1.6 400. Tracking tightens only on the big ones (-.04em, -.035em, -.035em, -.02em). Weights 400/500/700/800.
- Lowercase because the README and brief say that is Alex's voice. Headings are sentences, not labels. No eyebrows, no mono captions, no numbering.
- Measure 64ch for body; s4 text 30em.

## Colour
- Light ground `#fcfbf9`, ink `#0c0a09` (the promo's near-black). Grey guess `#6d6862` (about 5:1 on the ground). Red `#c42a14` for the filler strike and focus rings. Peach marker `#ffd9a8` (promo peach) for just-settled words and the yap row of the table. Rule `#d9d4cc`.
- Dark (follows the system): ground `#0c0a09`, ink cream `#f6ead4`, guess `#9d958b`, red `#ff6a52`, marker `#6b4416`. The pinned panel and code blocks invert.
- Colours mean things: grey is unsure, ink is settled, red is dropped, peach is just fixed. No gradients, glows or textures.

## Shape
- Two radii: 14px (panel, code blocks, button, the demo gif) and 4px (key caps, marker, inline code). No shadows except one flash ring on the paste moment.

## Motion
1. Guesses firm up (text swap, marker fades over 1.8 s) when they reach the upper 65% of the screen.
2. Fillers: strike line draws (.3 s), then the word collapses out of the line (.4 s).
3. Paragraph colour grey to ink (.4 s) as it settles.
4. The pinned teeth's jaw opens with scroll speed, like it opens with mic level, and closes when pasted. One flash on the install block.
Scroll is native. `prefers-reduced-motion`: no jaw, no marker fade, fillers stay struck instead of collapsing. No JS: the final words show and fillers are struck through.

## Evidence
Real README text and numbers only (table, caveats, cleanup levels, socket path, context json). 1.3 gb vs 0.1 gb are set at their real 13:1 ratio from about 1300px wide up; on narrow screens the ratio is compressed. demo.webp is the real app.
