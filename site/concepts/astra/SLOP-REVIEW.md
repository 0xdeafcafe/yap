# Anti-slop review

Reviewed against the complete rush `site/ANTI-SLOP.md`. This is a concept, not a claim that every checklist item has magically passed. The two largest exceptions are the illustrative replay and the typography’s unusually broad size range. Both serve the actual product behaviour and are disclosed below.

## Type

- Chosen Mac typography: Helvetica Neue, with explicit Helvetica/sans fallback. No Inter, Geist, Arial, fashionable free display face or unlicensed font files. Menlo is only for actual shell commands and a socket path.
- No serif/mono combination, italic accent word, gradient type, all-cap chrome, tracked eyebrows, decorative numbered headings or monospace H1.
- Lowercase is the README and brief’s voice, not a borrowed fashion. Product names, ⌘V, Redis and the example correction retain meaningful casing.
- Text weights are 400/500/700. All body and secondary text is at least 16px. Prose is narrow, with roughly 1.5–1.55 leading. No full-width paragraphs.
- **Deliberate exception:** the exact six-size ceiling is exceeded. A 184px wordmark and descending 72/48/24 sample are fundamental to “words shrink as they pile up”. The real-time replay adds intermediate sizes; narrow layouts also need optical adjustments. All values are recorded in DESIGN.md.
- Tight leading and tracking are confined to display text and the large editable sample. No title case, em dashes in page prose, decorative middle-dot separators or repeated uppercase metadata.
- No webfonts are declared, so there is no failed font request concealed by a fallback. The primary Mac face is intentional, with legible fallbacks for other OSes.

## Colour

- White is the main reading surface; broad toy-red columns frame it. No purple/blue gradients, parchment/serif/terracotta cluster, shadcn defaults, glass, bloom, neon glow or palette-cycling cards.
- The real teeth illustration contains its original gradients and highlights. This is a supplied product asset, not a page-wide treatment.
- **Dark-mode qualification:** charcoal and red exist together in system dark mode. The red is two full-width editorial columns, not a single acid accent behind a dashboard. A complete light design is the default when the system requests light.
- Text contrast was calculated: ink/red 4.94:1, muted/white 6.67:1, dark-mode muted/ground 7.68:1, enamel/panel 13.93:1, ink/white 18.21:1. Quiet dividing rules are not text. Disabled controls intentionally appear subdued.
- No decorative texture, grid overlay or noise. The actual column boundaries and staged text give the ground a reason to exist. One accent, neutral surfaces, no shadows.

## Layout and components

- Not a centred hero or the standard landing-page sequence. It is a continuous horizontal reading strip with seven content-dependent widths and a vertical phone adaptation.
- No pill above the title, blinking status dot, logo cloud, feature-card row, bento grid, icon tiles, emoji bullets, pricing tiers, fake testimonials or duplicated footer link grid.
- No numbered steps or made-up statistics. The memory bars are a proportional 1.3 GB versus 0.1 GB comparison from the README, beside its full sourced benchmark table and caveat.
- The listening panel is the only substantial rounded content surface. Its radius comes from `Pill.swift`. Text, benchmark, commands and install instructions have no card containers.
- No fake traffic lights or title bar. The editable field is a real textarea. No fake desktop around the real recording.
- No background grid, decorative page counts, vertical labels, badges or infinite marquee. The lower progress line reports the real horizontal scroll position.
- Three meaningful radii and an eight-pixel spacing rhythm. Whitespace varies by column. The hand-placed teeth interrupt the wordmark without making it unreadable.
- Focus states, semantic links/buttons, title, description, favicon, real alt text and an explicit textarea label exist. Status is announced politely, without announcing every transcript phrase.
- **Fixed after screenshots:** later columns clipped at the bottom. Shortened the actual recording’s frame, removed unnecessary line breaks from the numbers/vocabulary headings, and reduced one gap. Native column overflow remains available for expanded details and larger text. It is not needed in the default checked layouts.
- **Fixed after screenshots:** the rotated teeth extended the mobile document by one pixel. Moved the crop inwards. Document width now equals the viewport at 390, 768 and 1440.

## Product / developer-page tells

- Exact Homebrew tap and cask commands. No invented shell output, `$` prefix, fake terminal or installation pill.
- No GitHub star badge, developer mad-lib, glowing dashboard, cursor-logo, stock effect library or generic “get started”.
- The fn button genuinely controls the sample. The two compact shortcut rows explain real app behaviour. They are not ornamental keycap collections.
- All source links point to the actual yap repository and the README’s existing anchors. Privacy copy is backed by the repo, as requested by the brief.
- **Deliberate exception:** the interactive sample is constructed copy, not recorded recognition output. It explicitly says “a sample replay. no microphone.” and identifies its destination as an editable field. The next column supplies the actual app recording, behind a real play/stop control. No speed or accuracy claim is inferred from the sample.
- No false implication that browser fn captures system dictation. Hold the on-page button, or use Space/Enter while it has focus. The actual app’s fn usage is explained separately.
- Real names: fn, ⌘V, esc, Redis, SpeechTranscriber, rush, `~/.config/yap/live.sock`. No builder artefacts or unrelated product names.

## Motion

- No reveal library, parallax, mouse-following blob, spring, count-up, animated headline, lift-on-hover or autoplay marquee.
- Native scrolling only. No wheel handler or transformed page, snap points, scroll-speed changes or scroll hijacking. Arrow controls and section links offer an alternative to horizontal trackpad movement.
- Two small animation families: colour feedback and transcript size. Phrase arrival is the action being demonstrated, not letter-by-letter typewriting.
- **Qualification:** native smooth scrolling across the entire strip can last over 500ms because the browser chooses its duration. No authored animation exceeds 300ms. Reduced motion disables smooth scrolling and all CSS transitions.
- Reduced-motion replay shows all words immediately and waits for the user to paste. The actual animated recording is always opt-in and has a stop control, including with reduced motion enabled.
- No motion begins on hover or loops on load. Pointer release pastes, Escape cancels, losing focus cancels. All buttons do something and keyboard activation is tested.

## Copy

- Facts are from the README, with the user’s correction taking priority for cleanup defaults. Medium is explicitly the default. No claim that Apple Intelligence cleanup is off by default.
- No inflated accuracy promises. The benchmark’s limited sample and lack of human ground truth are written directly below the table. The page says it is not the most accurate engine.
- No adjective stacks, marketing clichés, negation lists, contrast reveals, rhetorical question/answer setup, aphorisms, feature mad-libs or generic FAQ.
- “hold fn, talk, let go” is the real product operation required by the brief, not a fabricated tricolon slogan.
- First person is reserved for the actual reason Alex wrote yap. Specifics replace invented praise. The install heading is the one small verbal wink, not a slogan on every column.
- No testimonial, invented customer, unnamed authority or made-up user count. Uneven paragraph lengths and distinct sections follow the product story.
- The broad headline alone could describe another dictation tool. **Qualification:** its neighbouring fn control, teeth, shrinking panel, exact paste behaviour, cleanup explanation and local socket cannot be transferred unchanged to a generic product. The swap-the-logo test applies to the composition rather than pretending four words are a unique invention.

## Craft and finish

- Squint test: a red mast column, two big shrinking specimens and a paste column. It does not collapse into hero/button/cards.
- Side-by-side character: an actual horizontal editorial strip with real Mac key behaviour is a clear visual idea. Nothing borrowed from rush’s bottle metaphor, Sounding’s player or terminal-decline’s palette.
- Design started from the transcript seed, the real yap recording, supplied teeth and `Pill.swift`. Tokens and exceptions are written in DESIGN.md.
- Screenshot loop completed. Required captures: `shot-desktop.png` (1440×900) and `shot-mobile.png` (390px wide, full page). Also checked `shot-tablet.png`, `shot-dark.png` and `shot-numbers.png`. Read each as an image and corrected layout problems.
- Chromium checks passed: replay/paste, cancellation preserving edited text, keyboard hold/release, next-column navigation, install anchor, clipboard feedback, recording play/stop, reduced motion, missing images, default content fit and outer-document width at 390/768/1440. No page errors.
- Exact scanner patterns from the checklist were checked in HTML/CSS/JS. Zero matches. The pattern names in this review and external source references are not shipped styling.
- Favicon, supplied social card, local 404 page with distinct metadata, source links, meaningful alt text and all required review files are present. The 404 handler needs the eventual host to serve `404.html`, which a local file cannot configure. The relative social image needs the eventual site origin for a fully qualified social URL.
- No commit, push, package install, framework, build output or remote font dependency. All website files are in `site/concepts/astra/`.

## Remaining limitations

This demonstrates the interaction with a fixed sample, not browser speech recognition. The real app is shown separately. The page never asks for microphone access. Phones switch to vertical order; keeping horizontal newspaper columns at 390px would make the text and operation harder to use. This is a deliberate responsive choice, not unfinished desktop styling.
