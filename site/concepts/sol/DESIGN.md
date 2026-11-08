# yap, the carton and the instruction sheet

The icon is already a product photograph of a small, slightly ridiculous physical object. This page treats that object seriously: a white toy carton with red printing, a silver winding key, an operating diagram and a specification plate. The face of the box says what to do. A perforation opens onto a folded instruction sheet. The large red engine comparison is the box's back panel, including the numbers where other engines beat yap. It is contemporary packaging, without fake distress, vintage lettering, safety stamps, serial numbers or invented certification marks.

## References and source of truth

Read `site/BRIEF.md`, the complete root `README.md`, rush's `site/BRIEF.md` and `site/ANTI-SLOP.md`, its bottle and zine implementations, Sounding's `docs/index.html` and `styles.css`, and terminal-decline's `docs/brand/README.md`. The transferable lesson was that the existing product object should dictate the design. This page does not reuse those sites' layout or artwork.

The initial visual reference is yap's own `icon/icon-1024.png`, followed by `promo/teeth.svg`. The SVG is reproduced inline from that source so the original jaw and key can move independently. `assets/teeth.svg` retains the original. The favicon is the supplied menu-bar teeth SVG, coloured in the page's red ink rather than loading the 915 KB app icon into a browser tab. The social image is the supplied `promo/social.png`. The app recording is an unmodified copy of `screenshots/demo.webp`. Its PNG still is a frame captured from that recording, not invented product UI.

All factual claims and installation commands come from the README, with one explicit user correction taking precedence: cleanup has light, medium (default) and heavy levels. The expandable cleanup explanation includes that distinction and the supplied John/Sarah example. The comparison numbers are the README's existing benchmark, not a new measurement of the updated cleanup modes.

## Colour

| Token | Value | Reason |
| --- | --- | --- |
| red | `#cf301e` | Red plastic translated into darker printing ink. White text on this red and red text on white clear 4.5:1. It prints the name, controls and comparison panel. |
| ink | `#251b17` | Warm dark brown sampled conceptually from the mouth cavity. Makes the line drawings feel related to the object. |
| muted | `#6b5147` | A legible, warmer secondary ink, rather than generic cool grey. |
| white | `#ffffff` | White carton and instruction stock. Cream remains in the actual teeth, making them the warmest object on the page. |
| fold | `#f1eeeb` | A narrow crease in the instruction sheet, rather than a general parchment ground or texture overlay. |
| line | `#d8cbc4` | Quiet warm rules separating operating notes and installation content. Never used for text. |
| button-depth | `#832619` | The dark side of the one physical pushbutton. |
| white rule | `#ffffff66` | Translucent white table dividers, not text. |

The single background gradient is the 24 px wide instruction-sheet crease. The supplied illustration retains its original enamel, plastic and metal gradients. They depict materials in the real mascot, not a decorative ambient glow. The full source values remain in `assets/teeth.svg` and the inline copy.

The default surround is red. In system dark mode it becomes ink; the physical white carton stays white. This is an intentional fixed-light document, not an inverted copy of a dark SaaS theme. No theme toggle or stored preference is needed.

## Type

Display: `Arial Rounded MT Bold`, then `Arial Rounded MT`, then `Trebuchet MS`, then the browser's sans. The rounded terminal shapes refer to the enamel teeth and moulded toy packaging. This is a deliberate macOS font choice. It is installed on the target platform, requires no network fetch and is not redistributed. Trebuchet preserves a broad humanist feel where the rounded face is unavailable. The intended macOS rendering was checked through Chromium's platform-font report.

Body: `Helvetica Neue`, then `Helvetica`, then sans. Its quiet, compact forms are appropriate to an operating leaflet, and it is present on the app's only supported platform. This isn't the browser's unchosen system default. Commands use `Menlo`, then `Consolas`, then monospace, solely because command characters and line breaks matter there. Captions use the same proportional body face. Nothing is set in tiny tracked capitals.

Six content roles: 16 px notes/commands, 18 px body, 24 px lead/operation title, 32 px small section title, 32–48 px main section title, and a fluid 56–144 px primary display. The final installation title uses the display role at 48–80 px. The wordmark is a separate 48/64/72 px brand mark. Regular and bold only. Prose line-height is 1.6, the short lead 1.4, and display 1.02–1.08. Tight tracking applies to display text and the wordmark, not body text. Lowercase follows the actual README and explicit brief, rather than an applied visual filter. “Redis” and “Sarah” retain their spelling.

## Geometry and spacing

Content boxes are square. The only UI corner token is 3 px, used for the mechanical installation button, copy button and spec plate. The curved geometry of the illustration is the product artwork, not an additional component radius system.

One shadow: `0 4px 0 #832619`, reduced to `0 2px 0 #832619` as the installation button presses down. No ambient card shadows. The illustration's grounding shadow is original source artwork.

The underlying spacing unit is 8 px: 8, 16, 24, 32, 40, 48, 56, 64, 72, 80 and 104. Responsive internal gutters interpolate from 24 to 64 px. 1/2 px rules indicate print, perforation or engraving. Optical exceptions: 3 px corner radius; 4/6 px underline and focus offsets; 6/12 px dense-table padding and small alignment corrections; negative display/illustration margins; and the existing source illustration coordinates. These aren't a second spacing grid.

The carton has a maximum width of 1512 px, a 24 px desktop surround, 16 px tablet surround and 8 px phone surround. The opening face is asymmetrical. Subsequent sections change measure and density: diagram, real recording, a two-column explanation, wide specification plate, short integration note and installation instructions. No repeating feature-card components. The phone diagram changes into a vertical operation sheet rather than squeezing three tiles into a row. The comparison fits the phone without horizontal scrolling. The command block wraps without changing the copied command string.

## Motion and interaction

- The SVG upper jaw rotates about its actual hinge at `(112, 218)`. One chatter cycle is roughly 270 ms. The butterfly key compresses horizontally as it turns on its existing axle. Scrolling triggers chattering while the object is visible, with a 180 ms stop tail. The page never pins, moves at a different scroll speed or intercepts scrolling.
- Pressing the illustrated “give it a wind” control triggers 1.2 seconds of the same mechanical action. It does not delay any navigation. Nothing chatters indefinitely on load. No motion library.
- The install button moves down 2 px over 180 ms `ease-out`; its physical depth decreases to match. This is a pressed button, not a floating card.
- The actual app recording starts paused, with explicit play and pause controls. Pausing restores a captured still. No synthetic speech, microphone permission request or invented transcript is used.
- Reduced motion stops and resets the jaw and key, disables smooth scrolling and button transitions, and pauses the recording. Winding then gives a static text acknowledgement. A user can explicitly play the recording.
- Copy uses the Clipboard API when available. A file-origin or denied-clipboard fallback selects the exact commands and tells the user to press ⌘C. No dead copy button on `file://`.
- Cleanup uses a native keyboard-accessible disclosure. Navigation and installation work without JavaScript; scripted-only controls stay hidden until their code runs.

## Delivery

Open `index.html` directly. No build step, server, framework, remote font, CDN, analytics or remote asset requests. External links are the real repository, its README anchors, release page and Alex's GitHub profile. The supplied social image and relative Open Graph URL will need the chosen production origin when this concept is deployed. `404.html` is supplied; server routing is a deployment concern.

Screenshots: `shot-desktop.png` at 1440 px, `shot-mobile.png` at 390 px, and an additional `shot-tablet.png` at 768 px. Captured with the Chromium binary in `~/Library/Caches/ms-playwright`, driven by the locally cached Puppeteer API. No browser download was needed.
