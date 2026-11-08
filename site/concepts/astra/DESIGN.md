# A strip of dictation

The page is one long piece of speech, set in columns. A loud red opening holds the actual fn gesture, then the same sentence gets smaller as it fills a listening panel and lands in an editable field. Keep moving right for the real recording, the reason Alex built yap, its vocabulary and cleanup, and the install commands. This comes from the app’s expanding edge panel and the brief’s transcript-tape seed: newspaper column divisions, but no fake paper, issue numbers or editorial costume. On phones, the strip unfolds downwards in the same reading order. The key, words and paste are the identity, with the actual chattering teeth interrupting the large yap wordmark.

## References and facts

Read `site/BRIEF.md`, the complete root README, rush’s site BRIEF and ANTI-SLOP checklist, its zine concept, Sounding’s site HTML/CSS and terminal-decline’s brand specification and design material. Rush is useful for confidence in flat colour and actual product evidence. Sounding is useful for how its visual language relates to the app. Neither layout is copied. The direct motion reference is yap’s `Pill.swift` and the supplied recording. The site intentionally does not reproduce the product’s glass shader.

Product claims and all benchmark values come from the README. The user’s correction overrides its outdated cleanup paragraph: light handles um/uh/stumbles, medium is the default and also handles punctuation and grammar while retaining words, heavy also removes taken-back material and makes bullets. The sample sentence is illustrative, explicitly labelled as a replay, not a benchmark or speech-recognition result. The actual app recording is separately identified.

## Colour tokens

| Token | Light | Dark | Why |
| --- | --- | --- | --- |
| `--paper` | `#ffffff` | `#24211e` | Plain white reading surface, then a warm charcoal from the product family. No parchment texture. |
| `--ink` | `#171513` | `#f6ead4` | Near-black type in light mode and the actual enamel cream in dark mode. |
| `--muted` | `#625b56` | `#bcb2a7` | Brown-grey secondary copy derived from the teeth and UI, with readable contrast. |
| `--rule` | `#c9c2bc` | `#766d64` | Quiet dividing rules, never used for body text. Main column boundaries use ink. |
| `--red` | `#f3452b` | same | A brighter version of the toy’s gum red, flat and broad. The page begins and ends with it; it is not a tiny neon accent on black. |
| `--red-ink` | `#171513` | same | Fixed dark text on red in both schemes. |
| `--panel` | `#211e1b` | `#100e0d` | A contained dark product panel, not a page-wide dev-tool theme. |
| `--enamel` | `#f6ead4` | same | Teeth colour, used for the listening text and active fn key. |
| `--field` | `#f1eeeb` | `#37312c` | Brief paste feedback and benchmark row emphasis. |

The recording has a `#0c0a09` backing in light mode and `#100e0d` in dark, matching the asset. Gradients exist only inside the supplied illustrated teeth SVG. There are no page gradients, overlays or shadows. Native form/browser focus rendering is replaced with a three-pixel ink outline and five-pixel offset.

## Typography

Helvetica Neue is deliberate: this is a Mac app, and that face belongs to Mac typography before the current generation of SaaS fonts. Its tight, ordinary lowercase lets scale do the expressive work. Helvetica and the browser sans face are explicit cross-platform fallbacks. No downloaded fonts or silent missing webfont declarations. The system font files are not redistributed. Menlo, then Consolas and the browser monospace face, is reserved for real commands and file paths. No mono headings or chrome.

Body is 18px at 1.55 line height. Supporting copy and controls are 16px at 1.5. Functional headings and the final transcript use 24px. Editorial display is 56px, with 48/40px adaptations for narrow measures, 72px for the beginning of the transcript and install heading, and a 184px wordmark. These are intentional optical adjustments to an underlying 16/18/24/48/56/72 scale, rather than unrelated sizes per component. The demonstration dynamically uses 48/40/32/28/24px to show the real shrinking behaviour. This exceeds the checklist’s ideal six total sizes; that exception is the concept’s subject. Tracking is tightened only for display and the large editable sample. Weights are 400, 500 and 700.

## Geometry

An eight-pixel spacing unit: 8, 16, 24, 32, 40, 48 and 64. Main columns use 32px inset; the listening demonstration gets 40px; phones use 24px. Different widths reflect different content: 400px for the opening, 560px for speech, 480px for the paste, and larger evidence columns. These are continuous pages divided by one-pixel rules, not cards. No rounded text containers, faux window chrome or decorative grid overlay.

Three radii: zero on the editorial layout and paste field, 16px on the interactive fn key and small blob parts, 26px on the listening panel (from `Pill.swift`). The teeth artwork carries its own illustrated geometry. No box shadows. The fn key is a functional control, not a decorative shortcut chip. The custom teeth crop overlaps the yap wordmark without hiding its letters.

## Motion and interaction

Native horizontal overflow on desktop. No wheel listener, transformed scroll scenes, inertia layer, snapping or scroll-speed adjustment. A trackpad, native scrollbar, focused scroller’s keyboard support, section anchors and explicit previous/next buttons all work. Phones use normal vertical page scrolling.

Two motion families: colour feedback over 180ms and transcript resizing over 200ms. Both use `cubic-bezier(.2,.7,.3,1)`, a quick settled response without a spring. Sample chunks appear every 700ms because that represents speech arrival, not interaction lag. They arrive as phrases, never letter-by-letter typewriting. Paste highlighting lasts 300ms. Nothing moves on arrival or loops unattended. Native smooth navigation uses the browser’s timing, which can exceed 500ms over the full long strip.

Hold the on-page fn control with a pointer, Space or Enter to accumulate the sample, then release to paste the current text into the editable field. The separate replay control makes the complete sequence available on phones and to people who cannot hold a button. Escape, pointer cancellation, loss of focus or hiding the tab cancels without replacing the field. Browser fn interception and microphone access are deliberately not involved. Status changes are announced with a polite live region.

Reduced motion disables all transitions and smooth scrolling. Replay reveals the full text immediately, then waits for another activation to paste. The real animated WebP is not loaded until someone explicitly presses “play recording”; its stop control restores a static captured frame, including in reduced motion.

## Delivery

Open `index.html` directly from disk. No server, build, network dependency, framework, CDN or installed font required. All assets live here. The copy control handles unavailable file-origin clipboard access by selecting the exact commands and explaining ⌘C. GitHub links are real repo and README anchors. The favicon is the actual app icon. The supplied social card is local. `404.html` offers a direct route back to the site with its own title and description.

`check.cjs` is a local verification harness, not shipped JavaScript. It uses the preinstalled Playwright and cached Chromium supplied in this workspace. The required screenshots are `shot-desktop.png` at 1440px and `shot-mobile.png` at 390px, with tablet and dark checks alongside them. No commit or push.
