# Icon

A wind-up chattering teeth toy: red-orange enamel jaws mid-chatter, cream teeth, little feet and a silver winding key, on a cream tile. Yap is for people who yap.

`icon-1024.png` is the master, generated from the prompt in `PROMPTS.md`. To rebuild the sizes macOS uses:

```sh
cd icon
for s in 16 32 128 256 512; do
  sips -z $s $s icon-1024.png --out AppIcon.iconset/icon_${s}x${s}.png
  sips -z $((s*2)) $((s*2)) icon-1024.png --out AppIcon.iconset/icon_${s}x${s}@2x.png
done
iconutil -c icns AppIcon.iconset -o AppIcon.icns
```
