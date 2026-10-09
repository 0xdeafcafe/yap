# Yap app icon

`Yap.icon` is the editable Icon Composer source for macOS 26 and later. It keeps the vermilion chattering-teeth toy, cream teeth, little feet, and silver butterfly key. Open the package in Icon Composer to edit it; no Xcode project is required.

## Composition and appearances

The document has two rendering planes: a native background fill and one transparent illustrated foreground in the **Wind-up toy** group. The enamel, teeth, key, and feet deliberately remain one coherent PNG rather than separate cutouts with potential registration seams. There is foreground/background depth, but no independent depth between those toy parts.

- `Yap.icon/icon.json`: composition, materials, and appearance overrides.
- `Yap.icon/Assets/toy.png`: 1024 × 1024 RGBA foreground, generated as a background extraction from the selected artwork. No cream tile, tile edge, or floor/drop shadow is baked into this asset. Intrinsic enamel reflections and mouth shading remain.
- Default background: native cream-to-sand gradient, `#FFF8E3` to `#EDD3A5`.
- Dark background: native warm plum-charcoal gradient, `#34252E` to `#151014`; the toy keeps its vivid original colors.
- Mono (`appearance: tinted`): automatic fill/luminance conversion, shared by Clear Light/Dark and Tinted Light/Dark. Bright teeth remain distinct from the dark open mouth. The system chooses the actual tint.
- Foreground: scale 0.9, centered; Liquid Glass enabled, combined lighting, specular enabled, neutral system shadow at 0.35. Translucency is disabled for Default/Dark and set to 0.18 for mono.

The source canvas is a full 1024 px square. The system supplies the rounded mask, exterior edge, lighting, and outer spacing. Do not add the old inset rounded tile or transparent outer margin to the background. The foreground retains breathing room inside the new grid. Apple's current HIG does not prescribe a separate numeric macOS safe-zone inset; use its template/grid and inspect the key and feet at small sizes.

Appearance properties use a single `*-specializations` array, including an unqualified default entry. Do not also add the corresponding base property: in the tested compiler, mixing `fill` with `fill-specializations` discarded the appearance overrides. The same convention is used for translucency. Apple does not publish a stable JSON Schema for this document format; validate manual JSON changes with the installed compiler and renderer.

## Build

Select a full Xcode 26+ installation with `xcode-select`, or set `DEVELOPER_DIR` to its `Contents/Developer` directory. From the repository root:

```sh
mkdir -p .build/tmp
TMPDIR="$PWD/.build/tmp" ./bundle.sh
```

`bundle.sh` invokes `xcrun actool icon/Yap.icon` with `--app-icon Yap`, `--platform macosx`, `--target-device mac`, and `--minimum-deployment-target 26.0`. It compiles into `.build/icon-assets`, checks that `Assets.car` exists and that the compiler's icon name matches `Info.plist`, then copies the catalog into `Yap.app/Contents/Resources` before signing.

`CFBundleIconName=Yap` selects the native icon stack. `CFBundleIconFile=AppIcon` and `Resources/AppIcon.icns` retain the existing legacy fallback. The compiler also emits `Yap.icns` and a partial plist; these are build intermediates. Its `CFBundleIconFile=Yap` is deliberately not merged over the separately named fallback. A failed icon compilation stops the build instead of producing a legacy-only app.

`icon-1024.png`, `AppIcon.iconset`, and `AppIcon.icns` remain the original fallback artwork; they are no longer the modern icon's master. The generation prompt is in `PROMPTS.md`.

## Preview and verify

The preview script requires Pillow and the Icon Composer renderer included with Xcode 27. It does not synthesize Liquid Glass effects:

```sh
python3 icon/render-previews.py
assetutil --info Yap.app/Contents/Resources/Assets.car
codesign --verify --deep --strict Yap.app
```

`render-previews.py` exports Default, Dark, ClearLight, ClearDark, TintedLight, and TintedDark at 1024, 128, 32, and 16 pixels for both design generations 26 and 27. `ICTOOL` can override the renderer executable. The blue tint is a preview choice, not a fixed document setting.

- `glass-check.png` (not committed): all 48 native renders at their actual pixel sizes; view at 100% to assess the small icons. The checkerboard belongs only to the sheet.
- `previews/` (not committed): individual exports, plus a render of the built app through NSWorkspace/IconServices.
- `VERIFICATION.md`: build and validation results and their limits.

After artwork edits, rebuild the app and rerun previews. Review both mono light/dark variants: a bright enamel highlight alone is not a substitute for a legible tooth/mouth silhouette.

## References checked

- [Apple: Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
- [Apple: App icons HIG](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Apple: Create icons with Icon Composer, WWDC25](https://developer.apple.com/videos/play/wwdc2025/361/)
- [Apple: Say hello to the new look of app icons, WWDC25](https://developer.apple.com/videos/play/wwdc2025/220/)
- Xcode's macOS `Icon Composer Icon.xctemplate` / `___FILEBASENAME___.icon/icon.json` and its local `actool(1)` manual.
- [IconComposerModel's observed document fixtures](https://github.com/peterpoliwoda/icon-composer-template/tree/main/Tests/IconComposerModelTests/Fixtures), cross-checked with the actual Apple compiler. These are empirical examples, not an Apple schema specification.
