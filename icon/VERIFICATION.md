# Liquid Glass icon verification

Verified with Xcode 27.0 (27A5228h), actool 25094, on macOS 27.0 (26A428).

## Build and bundle

- Ran `./bundle.sh` with the selected Xcode developer directory and a repository-local writable `TMPDIR`.
- Icon compilation succeeded, then the Swift release build completed. Sparkle resolved and built successfully; there was no offline download failure.
- The completed `Yap.app` includes `Contents/Resources/Assets.car` and `Contents/Resources/AppIcon.icns`.
- Bundled keys: `CFBundleIconName=Yap`, `CFBundleIconFile=AppIcon`.
- The bundled catalog exactly matches `.build/icon-assets/Assets.car`; the fallback exactly matches `icon/AppIcon.icns`.
- `codesign --verify --deep --strict` passed, including Sparkle's nested executable and updater app.
- `plutil -lint` passed for the source and bundled Info.plist; `sh -n bundle.sh` passed.
- No app launch, installation, release, or commit was performed.

Catalog SHA-256:

```text
45c3575cddafabfedbf757ef9b05f2add54fbe210dbb7f1566b6d52c24727028
```

## Catalog evidence

`assetutil-info.json` is the full `assetutil --info` output from the app's actual bundled catalog. It contains `Yap` as three **IconImageStack** records, each with a 1024 × 1024 canvas and `LayerCount: 2`:

| Appearance | Native background | Foreground |
| --- | --- | --- |
| NSAppearanceNameAqua | Gradient-1, cream/sand | Wind-up toy IconGroup |
| NSAppearanceNameDarkAqua | Gradient-2, plum/charcoal | Wind-up toy IconGroup |
| ISAppearanceTintable | System-mapped background | Wind-up toy IconGroup |

The foreground group records retain `LayerHasLightingEffects`; their stack entries retain specular and shadow settings. The catalog contains both authored background gradients with their intended RGB colors. Clear and Tinted share the tintable/mono stack rather than requiring four independently named app icons.

## Render evidence

`glass-check.png` contains 48 exports from Apple's own `ictool`: Default, Dark, ClearLight, ClearDark, TintedLight, and TintedDark at 1024, 128, 32, and 16 pixels, for design generations 26 and 27. All output dimensions and nonempty images were checked. The individual images are in `previews/`.

The sheet places each image at its actual size. All variants preserve the open-mouth silhouette and bright tooth rows. Fine key/foot details naturally reduce at 16 px, and Tinted Dark is subdued by the system's chosen tint. Clear previews use the renderer's neutral backing; the checkerboard outside each icon is only the contact sheet background.

`previews/bundle-default-1024.png` was rendered directly from the built app using `NSWorkspace.shared.icon(forFile:)`, without launching Yap. It shows the new artwork and native system mask/spacing, with no extra grey legacy enclosure. This verifies that IconServices reads the compiled catalog rather than displaying the old fallback artwork.

The macOS 26 images use the renderer's `--design-generation 26` mode on the macOS 27 host. This is not a separate macOS 26 Dock/Finder runtime test. Wallpaper-dependent effects and future OS changes cannot be exhaustively guaranteed by exported previews. The checked bundle follows the native icon-stack path and its build fails if icon compilation fails.
