# yap website brief

A one-page site for yap. Made the way rush's and Sounding's sites were: several
agents each build one concept, we cut anything that reads as AI-generated, then
iterate the strongest hard.

## What yap is

Dictation for macOS. Hold fn, talk, let go, and the words are pasted wherever
your cursor is. It uses the speech model that ships with macOS, so nothing
leaves your mac and it's free. Mac only, macOS 26.

Install:

```sh
brew tap 0xdeafcafe/yap https://github.com/0xdeafcafe/yap
brew install --cask yap
```

The source of truth for every fact is `README.md` at the repo root. Read it in
full. Don't invent features, numbers or quotes.

## What's unique (lead with these)

1. **Hold fn, talk, let go.** No app to switch to, no window. A little blob
   sits on the edge of your screen, opens into a listening panel while you talk,
   words appear and shrink as they pile up, then it pastes. Double-tap fn for
   hands free, esc or fn+another key cancels.
2. **Tiny.** It replaced Wispr Flow, which sat on 1.3 GB of RAM and ~5% CPU all
   the time. yap sits on ~0.1 GB and only works while you talk.
3. **Nothing leaves your mac.** Apple's on-device SpeechTranscriber. Free.
   Transcripts kept 30 days, recordings off unless you turn them on.
4. **It learns your words.** Reads the window you're in for names and odd words
   (Redis, LangWatch), hears "reddis", writes "Redis". Learns swaps, drops
   fillers you keep deleting ("basically"). Never touches ordinary words.
5. **Honest numbers.** The benchmark table in the README: 8.6% error, 0.9 s
   wait, 0.1 GB — not the most accurate engine, and the page says so.
6. **Talks to other apps.** A live socket (`~/.config/yap/live.sock`) that rush
   uses to show your dictation in its message box as you speak.

## Assets you may use (copy into your concept folder)

- `icon/icon-1024.png` — the app icon: cream wind-up chattering teeth.
- `icon/variants/*.png` — alternative icons the app offers.
- `icon/MenuBarIcon.svg`, `promo/teeth.svg` — vector teeth.
- `screenshots/demo.webp` — the blob opening, words piling up, pasting.
- `promo/yap.mp4`, `promo/social.png`, `promo/index.html` — the launch video
  and the HTML it was rendered from. Its palette (near-black #0c0a09, cream
  #f6ead4, red #e5371f, peach #ffd9a8) is a starting point, not a rule.
- `Sources/Yap/Pill.swift`, `Teeth.swift`, `Looks.swift` — how the real UI
  draws and moves, if you want the site's motion to match the app's.

## Voice

Lowercase, plain, first person from Alex, short sentences, a bit dry. The README
is the voice. No marketing words ("seamless", "effortless", "supercharge",
"unlock", "blazing"). No em-dash-heavy copy.

## Inspiration (look, don't copy)

Look at how these were made and what makes them feel custom, then do something
of your own. Nothing should read as a copy of them:

- `~/Source/github.com/0xdeafcafe/rush/site/` — BRIEF.md, ANTI-SLOP.md and
  `concepts/*` (fleet, terminal, zine, bottle). The user likes this one most.
  **Read ANTI-SLOP.md and obey it** — it is the bar this site is held to.
- `~/Source/github.com/0xdeafcafe/sounding-tv/docs/` — index.html, styles.css,
  app.js; plus `Design/Branding`.
- `~/Source/github.com/0xdeafcafe/terminal-decline/docs/brand/` and
  `docs/design` — terminal-decline's brand.

## What we want

Be creative and get outside the usual landing page: no hero + three feature
cards + CTA. Odd layouts are welcome (horizontal scroll, column grids, the page
as a mac desktop, the page as a transcript, etc). The page should make you feel
what holding fn and talking is like. It may use the Web Speech API or the mic
for a live demo if that's well done and degrades gracefully.

## Rules

- Static: HTML, CSS, JS. No build step, no frameworks, no CDN. Self-hosted
  fonts are fine if you pick them deliberately (the file must be in your folder
  and licensed for it); otherwise justify the system stack.
- Everything lives in your own folder `site/concepts/<name>/`. Don't touch
  anything outside it. Open `index.html` straight from disk and it must work.
- Responsive down to a phone, `prefers-reduced-motion` respected, real text
  (not text baked into images), decent contrast.
- Write `DESIGN.md` in your folder: the idea in a paragraph, then every
  colour, font, radius and motion choice with why. And `SLOP-REVIEW.md`: go
  through rush's ANTI-SLOP.md honestly and say what you fail and fixed.
- Check it yourself: screenshot it at 1440 wide and 390 wide with the
  playwright chromium in `~/Library/Caches/ms-playwright` (e.g. `npx playwright
  screenshot`), save them as `shot-desktop.png` and `shot-mobile.png` in your
  folder, look at them, fix what's off. Repeat until you'd be proud of it.
- Don't commit. Don't push.
