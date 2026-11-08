# Slop review against rush's ANTI-SLOP.md

## Type
- Default fonts: the system stack is the risk. It is a decision (mac-only app, panel uses the system font), recorded in DESIGN.md. Falls back to Helvetica/Arial elsewhere. Pass with a caveat.
- Reflex fonts, serif+mono pairing, italic accent word, eyebrows, mono chrome, mono H1: none. The only italic is the grey guess state, which is a mechanic.
- Lowercase: it is the README's and brief's voice, but it also lands on headings and nav. Partial fail of "not lowercase as an affectation"; kept because the brief asks for the voice.
- Weights 400-800, body 18px/1.6, measure 64ch, five sizes. Pass. No gradient text, no Title Case, no em-dash copy.

## Colour
- No purple, no cream+serif+terracotta, no glow, no grain. Ground is near-white, palette is the promo's red/peach/near-black, used by meaning.
- Dark mode follows the system; its near-black plus red-ish accent resembles the "dev tool" look. Partial, noted.
- Contrast: guess grey about 5:1 light, about 6.5:1 dark.

## Layout
- No hero pill, centred hero, logo strip, three cards, stats row, numbered steps, card-wrapped blocks, fake window chrome, texture, marquee, carousel, pricing.
- 1.3 gb / 0.1 gb are two README numbers drawn at their real ratio, not a stats banner.
- The pinned panel echoes the real app's panel; it is not a status dot. It overlaps text at the bottom edge while scrolling, by design.
- Section rhythm varies: huge hero, two-column controls with the real gif, number scale, prose, table, code.
- No terminal mockup; code is real commands/json from the README, no `$`, no copy button. `kbd` chips only for fn/esc inside the controls list.
- Nothing overflows at 1440 or 390 (scrollWidth checked); table scrolls on phones.
- Missing: 404 page. Favicon, title, description, og image set (og image is the existing promo/social.png).

## Motion
- No fade-up reveals; only colour settle, guess firm-up and filler drop, each carrying meaning. No typewriter (paste is instant). Native scroll. Reduced motion honoured. Durations .3 to .4 s except the 1.8 s marker fade.
- Weakness: the filler collapse reflows a line while you read it.

## Copy
- No banned words or "No X. No Y." lists. The numbers heading ("it isn't the most accurate one, and i'd rather say so") is near the "not X" pattern but states a real caveat. "this page is built the same way" is the one wink.
- Facts come from the README plus the coordinator's correction: cleanup has three levels (light, medium as default, heavy), not opt-in. The "tock"/"talk" guess and the "the the build is fine" example are mine and read as examples.
- Live demo uses the browser's recogniser (may send audio to its vendor) and says so. Chrome often refuses the mic from file://; the page says that too.

## Craft
- Scanner terms (`rounded-2xl`, `backdrop-blur`, `bg-clip-text`, `indigo-`, `shadow-lg`, `data-aos`, `whileHover`, `lucide`): no Tailwind, no hits expected.
- Screenshots at 1440 and 390 taken and fixed (tight tracking, oversized marker box, hero widow).
