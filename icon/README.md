# Yap — Spoken caret

A frosted speech droplet containing two voice pulses and an insertion caret, on a softly lit graphite tile. The shape connects talking to typing without a microphone, text label, rainbow, or literal interface screenshot.

## Regenerate

On this Mac (Python 3 with Pillow 12.3.0 and NumPy 2.5.3 already installed):

```sh
python3 icon/generate.py
python3 icon/validate.py
```

The default is the final revision, 3. `--revision 1` and `--revision 2` reproduce earlier design states; rerun without arguments to restore the final exports. Everything is resolved relative to the script; all writes stay in this directory. Rendering uses explicit vector geometry, analytical monochrome lighting, 2048-square supersampling, and Lanczos reduction. No generated imagery, downloaded art, or glyph font is part of the icon. SF Compact is used only for preview labels, with an Arial fallback. `/usr/bin/iconutil` packages the ICNS. The generator then probes its 16/32 px legacy ARGB decode. On this Mac, iconutil encodes straight alpha where its decoder expects premultiplied alpha; the generator repairs only those two payloads when the probe detects visible error. The other eight PNG representations are untouched. A complete round-trip validates the result.

## Concrete specifications and research

Research checked 9 October 2026.

- [Apple HIG: App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons/): 1024 × 1024 square layered artwork for Mac; centered, simple, filled foreground shapes; well-defined edges; unmasked full-bleed Composer background; system-applied corners/materials. The HIG change log includes refinements dated June 8, 2026. No nonessential icon text.
- [WWDC25 — Say hello to the new look of app icons](https://developer.apple.com/videos/play/wwdc2025/220/): ample breathing room on the new grid, rounded rather than sharp details, bold weights at small sizes, gentle background gradients, and restrained static effects in source layers. Applied here as a single large silhouette with three substantial strokes.
- [WWDC25 — Create icons with Icon Composer](https://developer.apple.com/videos/play/wwdc2025/361/): separate layers, material control and platform/appearance previews. SVGs are named in back-to-front order.
- [WWDC26 — Platforms State of the Union](https://developer.apple.com/videos/play/wwdc2026/102/): sharper icon rendering, refraction and multiple Liquid Glass layers. [Icon Composer for Beginners Group Lab](https://developer.apple.com/videos/play/wwdc2026/8012/) discusses the revised material and legacy previews. These are actual 2026 updates, not extrapolations from 2025.
- [Apple's practical Icon Composer guide](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer): SVG source, no baked mask, lighting or blur for import, background configured in Composer.
- [Setapp's Mac submission guide](https://docs.setapp.com/docs/submitting-apps-for-review): for the flattened Mac asset, use a 1024-square image, 824-square body and 100 px margin. This compatibility layout is distinct from full-bleed modern Composer input.
- [Apple Design Resources](https://developer.apple.com/design/resources/) provides the official production templates. The static compatibility export here uses a code-defined continuous superellipse (exponent 4.4), not an extracted Apple template path; Composer will supply the exact system mask when the clean layers are imported.

The flattened PNG/ICNS includes the 824-square body centered at (512,512), an external soft shadow, transparency outside, and an embedded sRGB profile. Final foreground nominal bounds: x 207–817, y 260–732, with optical centering above the tile midpoint. The monochrome palette runs from graphite around #232323–#3d3d3d to frosted silver. The 16/32 pixel representations have wider, pixel-aligned pulses and caret. All other sizes share the large artwork.

## Six concepts considered

1. **Spoken caret:** white/silver speech droplet on graphite, with voice strokes ending in a caret. Broad speech silhouette survives at 16 px; chosen because it shows speech becoming typed text.
2. **Liquid quotation:** two thick silver quotation marks on smoke, one lengthening into a cursor. Two strong shapes survive small sizes; runner-up, but less specifically dictation.
3. **Fn pebble:** a frosted keycap releasing a white speech bead. The bead/key silhouette survives, but the fn label and motion relationship weaken at 16 px.
4. **Paste drop:** a luminous droplet landing between dark text strokes on pearl. Simple drop/caret silhouette, but too suggestive of a clipboard tool.
5. **Y-shaped voice ribbon:** a broad white glass ribbon branching into a soft y on charcoal. One bold mark reads tiny; meaning requires learning.
6. **Listening aperture:** a smoky annulus surrounding a bright speech slit on silver. Large ring/slit survives small sizes, but suggests audio recording more than dictation.

## Visual iterations

All three previews were opened as images and inspected. The final 1024 master was also opened separately.

- **01 — Initial study:** speech read at small sizes, but ascending narrow strokes suggested signal strength. Tail was too pointed, bevel too heavy, dark tile weak against the dark proof background.
- **02 — First revision:** widened strokes, made voice pulses unequal, shortened/rounded the tail, enlarged the speech body, raised the tile's darkest value, reduced the bevel. The 16 px proof still softened the first two pulses together.
- **03 — Second revision / final:** optical stroke positions/weights for the 16 and 32 px rasters; stronger long caret; narrow lower refracted edge and subtle transmitted light. The silhouette and separate strokes remain legible in both proof backgrounds. Glass details are deliberately secondary at small sizes.

`preview.png` contains literal 1024, 256, 64, 32 and 16 px rasters side by side on light and dark rows. It also includes nearest-neighbor magnifications to reveal actual small pixels and a Dock row with three simple original stand-ins (Files, Browser, Notes). This is a designed mock, not a live screenshot or an actual system rendering test.

## Layer handoff

- `layers/01-background.svg`: full-bleed opaque graphite reference. Prefer recreating this as a native Composer background, using a subtle graphite gradient; do not import the compatibility tile as a modern background.
- `layers/02-speech.svg`: clean white/silver speech silhouette; apply the frosted Liquid Glass material in Composer.
- `layers/03-voice.svg`: two dark solid rounded pulses; retain strong contrast and minimize material treatment.
- `layers/04-caret.svg`: separate dark caret; treat like the pulses.
- `layers/background-rendered.png` and `foreground-rendered.png`: separate lit compatibility layers. These include static effects and are not the clean Composer input.

All SVG canvases are 1024-square. Their artwork expands the flattened icon's 824-square coordinates to full bleed, so Composer can apply its own outer mask/inset without double padding. Vector files have no outer rounded mask, blur, shadows, or raster content. The speech silhouette's own contour is intentional foreground geometry.

The delivered ICNS is a **static compatibility asset**, not a dynamic `.icon` package. Composer parameters and clear/tinted appearances need previewing during later integration. No application bundle, Info.plist, bundle script, or repository file outside `icon/` was edited by this task.

## Deliverables and validation

- `generate.py`, `validate.py`, `README.md`, `TASKS.md`
- `icon-1024.png`, `AppIcon.icns`, `preview.png`
- `AppIcon.iconset/`: 16, 32, 128, 256, 512 pt at both 1x and 2x (ten PNGs).
- `layers/`: four SVGs and two rendered PNG layers listed above.
- `iterations/`: `icon-01.png` through `icon-03.png`, and `preview-01.png` through `preview-03.png`.
- `validation/results.json`: dimensions, alpha, color profile, monochrome pixels, SVG parsing, and `iconutil` decode comparison for every ICNS representation: eight are pixel-identical; the two legacy ARGB sizes preserve alpha exactly and differ by less than one composited RGB level due to 8-bit premultiplication.
