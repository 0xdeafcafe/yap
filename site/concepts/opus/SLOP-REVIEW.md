# opus concept: slop review

Gone through rush's `site/ANTI-SLOP.md` item by item, after screenshots at 1440 × 900 and 390 × 844, light and dark, idle, hovering, listening and just pasted. "Fixed" means it failed in a build and was changed.

## Type
- Default fonts: the system stack is used, on purpose, and justified in DESIGN.md (the panel is SF in the app; yap is mac-only). A reviewer could still call it a default. **Borderline, argued.**
- Tasteful free fonts, serif + mono, italic accent word: none. Pass.
- Eyebrows, tracked mono labels: none. Pass.
- Mono at H1 size: no. Pass.
- Lowercase everything: yes, but the brief says the voice is lowercase and the README is. App strings keep their own case. **Deliberate.**
- Light weights: only 400 and 600. Pass.
- Scale: 16/19/24/40/112, body 19 at 1.6. The panel adds the app's 22/18/15/13 as a product exception. Pass with the exception noted.
- Measure: 36rem. Pass.
- Font loads: no web fonts declared. Pass.
- Gradient text: **one hit, kept.** The guessing words in the panel use `background-clip: text` for the light sweep, because that's what `Said` does in the app. It's never on a headline.
- Title Case, em dashes, middle dots: none in copy. The one "—" is the app's own "— let go to paste" hint. "settings › words" is a menu path from the README, not decoration. Pass.

## Colour
- Purple/indigo: none. Pass.
- Cream + serif + terracotta: avoided. Paper is white, the red is the toy's red and isn't used as a text colour, and there's no serif. Pass.
- Near-black ground with one neon accent: the dark mode is warm near-black with the red, which is close to that look. It's the system's dark mode, not the default, and the red is only the caret and one square. **Borderline in dark.**
- Glows, blooms: none. The edge light on the blob is the app's moving highlight, only while it's open. Pass.
- One dominant, one accent, one neutral: ink, red, warm greys, with peach only as a highlighter. Pass.
- Follows the system: yes, both designed. Pass.
- Tinted greys, contrast: warm greys, muted text ≥ 5.5:1. The panel's guessing words are dim on purpose (app fidelity) and sit around 3:1. **Partial fail, kept for fidelity.**
- Flat ground: white on purpose, it's a document. Pass.

## Layout and components
- Badge above hero, pulsing dot: none. The caret blinks, because it's a caret. Pass.
- Centred hero with two buttons: no, left aligned, no buttons except "use my mic". Pass.
- Stock section order: hero, edge, memory, words, privacy, numbers, socket, install. It follows the README's story. Pass.
- Feature cards, icon tiles, emoji: none. Pass.
- Numbered steps, stats row, count-up: none. The memory chart is the README's numbers, one square per 0.1 gb. Pass.
- Cards around content: none. Pass.
- Glass nav: none. The only blur is the blob, which is the product. Pass.
- Fake window chrome: none. Pass.
- Grid/dot/noise backgrounds: none. Pass.
- Marquee, testimonials, pricing, footer grid: none. Pass.
- Radii: 6 px everywhere on the page; the blob's radii are the app's. Pass.
- Section rhythm: varies (gaps 112 to 176, a chart, a key table, a benchmark table, live JSON). Pass, though every section is still "heading then paragraphs", which is what a document is.
- Focus, alt, favicon, title, description, 404: yes. The blob is a real button with a focus ring; Enter starts hands free and pastes. Pass.
- Overflow: checked at 390; the brew lines wrap on phones (fixed: they scrolled sideways before). Fixed.

## Dev-tool items
- Terminal mockups, fake output: none. The JSON lines are generated live by the page in yap's real format (sorted keys from `Live.swift`). Pass.
- Typewriter: the words arrive word by word in the panel. That's the product's own streaming at the app's demo cadence, not a headline typing itself. **Argued.**
- Install pill with copy: the install is a plain code block with a plain "copy both lines" button, the real brew route. Borderline, kept because people do want to copy it.
- Badges, stars, kbd decoration: kbd is used only in the key table and for "space", each a real key in context. Pass.
- "Built for" headlines: no; the headline is the action. Pass.
- Generic CTA, arrows: none. Pass.
- Unasked privacy reassurance: privacy is one of the brief's points, and the page is honest that the browser demo (Chrome) sends audio to Google while the app doesn't. Pass.
- Leftovers: none found. Pass.
- Real names: fn, ⌘V, `~/.config/yap/live.sock`, `words.txt`, `./bundle.sh`, rush. Pass.

## Motion
- Fade-up reveals, hover lifts: none. Pass.
- Bounce: the springs are the app's dampings (.86, .65 after a drag), not added for fun. Pass.
- Meaningful, two or three types: blob springs, caret blink, paste fade. Pass.
- Scroll-jacking: none. Space no longer scrolls the page, because it's fn here; the hint says so. **Trade-off, deliberate.**
- Reduced motion: honoured, as the app does it. Pass.
- Durations: UI 200 ms; the 0.9 s wait after letting go is deliberate (yap's real wait). Pass.
- Fake loading text: none. Pass.

## Copy
- Marketing words, negation lists, "it's not X", tricolons, colon reveals, aphorisms: checked; fixed one ("it's free because there's nothing to pay for", cut as performed cleverness). Pass.
- Headline could sit on a competitor's site? "hold fn, talk, let go." is close to generic dictation, but the blob doing it on the page is not. Borderline.
- Invented facts: none. Every number is the README's. Cleanup levels were corrected to the current app (light/medium/heavy, medium default) after the coordinator flagged the README as stale. The scripted dictations are labelled as "one of my dictations" and only say true things.
- Real evidence: the panel is a port of the app's code rather than a screenshot. `screenshots/demo.webp` isn't used (2.6 MB). Pass.

## Craft
- Squint test: a big black headline on white with a dark capsule on the right edge. Not dark hero + glow + cards. Pass.
- Swap-the-logo: the page doesn't work for anything but a hold-to-talk dictation blob. Pass.
- Tokens recorded: yes, DESIGN.md.
- Built from the reference (Pill.swift), then screenshot-and-fix loops: yes. Fixed in the loop: a class clash that put the memory chart's "yap" row on top of the hero, guessing words vanishing when they wrapped, the brew lines overflowing on phones, the memory row wrapping its label.
- Hand-set: the one-square-per-0.1-gb chart, the bridge curves.
- Social card: reuses `promo/social.png`. 404: `404.html`.

## Not done
- Web Speech on `file://` may be refused by Chrome; the page then falls back to the scripted dictation and says so. Not tested with a real mic in this session.
- No tablet-width screenshots.
- Safari not checked (clip-path `path()` and `createConicGradient` are supported there; the edge light is skipped where it isn't).
