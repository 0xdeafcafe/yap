# Anti-slop review

Reviewed against the complete rush `site/ANTI-SLOP.md`, not a reduced interpretation. The governing idea is the existing chattering-teeth object and its packaging. The tokens and exceptions are recorded in `DESIGN.md`.

## Type

Pass: no Inter, Geist, Roboto, reflexive geometric webfont, serif/mono pairing, italic accent word, gradient text, tracked uppercase chrome, decorative numbered labels or mono headline. Arial Rounded MT Bold is deliberately chosen for tooth-like rounded terminals and moulded-toy lettering. Helvetica Neue is the quiet operating-sheet face. Chromium's platform-font report confirmed Arial Rounded MT Bold really rendered the headline. No font files, network fetch or silent unlicensed font distribution.

Pass: body is 18 px, notes and commands are 16 px. Regular and bold only. Paragraphs have bounded measures. The six content roles and separate wordmark are documented. Display tracking is tight, body tracking is normal. Lowercase is explicitly required by the brief and established by the README; it is not applied with CSS. Proper names retain capitals. No em dashes, title-case headings or decorative separators.

Exception: the rounded face is a macOS platform font rather than a self-hosted face. This site advertises an app that requires macOS 26. The documented fallback remains legible on other platforms but will not have identical letterforms.

## Colour

Pass: white carton, one red printing ink and warm dark text. The cream belongs to the actual teeth, not a beige page theme. No serif, terracotta/sage palette, violet, gradients behind the object, neon-on-black developer styling, glowing shadow, shadcn palette or coloured feature-card cycle. Muted ink and rules are deliberately warm. The single narrow background gradient represents the physical fold; it isn't grain, a mesh, a bloom or a background pattern.

Exception: the physical document stays white in dark mode. The surround follows the system and becomes warm ink. The chosen light document is intentional, rather than an automatically inverted web-app theme. The mascot itself contains the original material gradients and grounding shadow. They are product artwork, not CSS decoration added to suggest polish.

## Layout and components

Pass: no eyebrow badge, status dot, centred two-button hero, logo strip, feature-card row, bento, emoji icons, rounded-square icon tiles, testimonials, fake metrics, pricing tiers, FAQ filler, marquee, carousel or footer grid. The hero's small RAM annotation comes directly from the README. There is no row of oversized stats. The required numbers live in a real engine-comparison table, not a marketing stats strip.

The operating sequence has exactly the three real actions, because that is how the app works and the brief explicitly requests it. It is a continuous line drawing, not three numbered cards. There are no invented 01/02/03 labels. On mobile it becomes a vertical instruction sheet.

The carton, engraved-style comparison plate and real screenshot each have a boundary because they represent distinct physical or evidentiary objects. Paragraphs and features do not each get a card. No nested cards, accent edge strips, glass, fake window chrome, rotated sidebar labels, crosshairs, grid backgrounds or noisy paper overlays. The headline and illustration have their own asymmetrical geometry. Sections vary in measure, length and density.

Fixed after screenshot inspection: the wind-up label collided with the silver key on phones; it now sits below it. The recording's original dimensions are 750 × 263, not the initial assumed dimensions; the incorrect crop was removed. A fixed-layout phone table with wrapping engine names fixed overflow at 320 px. A tablet-only illustration width fixed a separate 4 px overflow at 768 px. The header's joke was cut when it produced awkward wrapping.

## Product evidence and developer-page traps

Pass: the demo is the supplied recording, with an actual captured frame for pause. No fake transcript, abstract dashboard, terminal window, traffic lights, synthetic command output, typed animation, stars badge or open-source/version pill. The only large illustration is the actual mascot from the repository. The keys shown are the real fn and esc controls, in their operating context. No ornamental keycap row.

The real installation commands are copied verbatim. They are in a readable instruction block rather than a floating pill. “install yap”, “copy commands”, “get the latest release” and source links name their actions. No generic “Get started” or arrow glued to every link. Arrowheads belong to the mechanical diagram and installation navigation. Local-processing and privacy claims are central to the brief, sourced from the README, and linked to it. The live integration names rush.

## Motion

Pass: the toy's jaw and butterfly key move as actual mechanical parts. No generic reveals, cards lifting on hover, spring entrance, counter, typing effect, follower blob or animation library. Scrolling remains native and content never pins. The animation stops when the object is offscreen. Winding is a direct user action, not endless ambient chatter.

The recording starts paused. Its control returns to the still when paused. Reduced motion disables chattering, transitions and smooth scrolling, and pauses the recording. The winding control gives a static acknowledgement instead. Buttons have real actions and visible focus styles. The installation button's 2 px press is the only motion beyond the mechanism and real recording.

Exception: a complete wind-up demonstration takes 1.2 seconds. That is a few rapid jaw movements after immediate input feedback, not a 1.2-second transition or a navigation delay.

## Copy

Pass: specific, lowercase README-style language. No adjective stack, SaaS superlatives, negation list, “less X / more Y”, contrast reveal, rhetorical question-and-answer, tricolon slogan, wisdom aphorism, invented testimonial, round-number boast, synonym cycling or generic FAQ. Humour lives mainly in the box idea and “have a yap”, rather than every paragraph. The extra footer joke and mock registered-trademark symbol were cut.

The page admits the error rate is worse than the two best benchmark rows. The benchmark caveat states the sample, machine and consensus-based scoring. The learning explanation separates contextual word corrections from cleanup. The user's correction is reflected explicitly: medium cleanup is the default, light removes fillers and stumbles, heavy also removes retractions and formats lists. There is no claim that Apple Intelligence is off by default.

## Craft and finish

The squint silhouette is a white package with huge rounded red lettering, a recognisable teeth object and a red technical plate. The page cannot be swapped to another app without losing the key, fn instructions, speech behaviour, word learner and source numbers. The hand-drawn arrows, actual SVG hinge and fold make it specific without fake distress or “imperfect” random placement.

The source scanner found no occurrences of the checklist's banned utility/effect patterns in `index.html`, `style.css` or `app.js`: `rounded-2xl`, `rounded-3xl`, `backdrop-blur`, `bg-clip-text`, `indigo-`, `violet-`, `shadow-lg`, `data-aos`, `whileHover`, `from-purple`, `#6366f1` or `lucide`. The copy scanner also found no em dash or banned marketing verbs.

The finish includes title, description, theme metadata, a real teeth favicon, supplied social card, an intentional 404 page, working local navigation and descriptive image alternatives. The 404 shares the exact typography and colours. Social metadata uses a relative supplied image path because the final deployment origin has not been chosen. The hosting configuration must route missing pages to `404.html`; a static concept cannot configure a server.

## Browser verification

Screenshots were inspected at 1440 px desktop, 768 px tablet and 390 px phone, using the cached Playwright Chromium binary. Extra layout checks at 320 and 1920 px passed with no horizontal page overflow. The final image uses an actual frame showing the listening panel and words, captured through Chromium from the original animated WebP.

The pointer test found another real issue: the neighbouring text column's stacking context covered part of the winding button. The winding control now has an explicit higher stacking order. Its pointer click moves the jaw, and an observer restarts a pending wind if the object enters the viewport during the click.

Final browser results: winding pointer hit area passed; reduced-motion jaw reset and paused recording passed; recording play and pause passed; native cleanup disclosure passed; clipboard success (with a local stub) and file-origin selection fallback both passed. No browser JavaScript errors. Axe reported zero violations for its WCAG 2 A/AA and WCAG 2.1 AA rule sets with cleanup expanded. This is an automated check, not a claim of exhaustive accessibility certification. The 404 page also fits 390 px without overflow.
