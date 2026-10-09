#!/bin/sh
# Builds Yap.app next to this script.
set -e
cd "$(dirname "$0")"
# Compile the Icon Composer document, not a flattened app-icon image set.
# DEVELOPER_DIR can select an Xcode installation without changing xcode-select.
icon_output=.build/icon-assets
mkdir -p "$icon_output"
xcrun actool icon/Yap.icon \
  --compile "$icon_output" \
  --app-icon Yap \
  --platform macosx \
  --minimum-deployment-target 26.0 \
  --target-device mac \
  --output-partial-info-plist "$icon_output/Info.plist" \
  --output-format human-readable-text
# Fail the build instead of silently shipping a legacy-only icon.
test -s "$icon_output/Assets.car"
icon_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$icon_output/Info.plist")
test "$icon_name" = "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' Info.plist)"
swift build -c release
rm -rf Yap.app && mkdir -p Yap.app/Contents/MacOS
cp .build/release/Yap Yap.app/Contents/MacOS/
cp Info.plist Yap.app/Contents/
mkdir -p Yap.app/Contents/Resources
cp "$icon_output/Assets.car" icon/AppIcon.icns icon/MenuBarIcon.svg Yap.app/Contents/Resources/
cp -R icon/variants Yap.app/Contents/Resources/Icons
# A stable identity keeps macOS's Accessibility permission across rebuilds; ad hoc means re-granting each time.
# Best first: Developer ID (shareable), Apple Development, then the local self-signed one.
ids=$(security find-identity -v -p codesigning)
identity=-
for want in "Developer ID Application" "Apple Development" "Yap Local Signing"; do
  found=$(printf '%s\n' "$ids" | grep -o "\"$want[^\"]*\"" | head -1 | tr -d '"')
  if [ -n "$found" ]; then identity=$found; break; fi
done
# Sparkle, the updater. Yap isn't sandboxed, so it doesn't need Sparkle's XPC services.
mkdir -p Yap.app/Contents/Frameworks
ditto .build/release/Sparkle.framework Yap.app/Contents/Frameworks/Sparkle.framework
rm -rf Yap.app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices
for part in Versions/B/Autoupdate Versions/B/Updater.app ""; do
  codesign --force --options runtime --sign "$identity" "Yap.app/Contents/Frameworks/Sparkle.framework/$part"
done
entitlements=Yap.entitlements
case "$identity" in
  "Developer ID"*|"Apple Development"*) ;;
  *) # No Team ID, so the hardened runtime would refuse to load Sparkle unless library validation is off.
     entitlements=.build/Yap.entitlements
     cp Yap.entitlements "$entitlements"
     /usr/libexec/PlistBuddy -c 'Add :com.apple.security.cs.disable-library-validation bool true' "$entitlements" ;;
esac
codesign --force --options runtime --entitlements "$entitlements" --sign "$identity" Yap.app
echo "signed with: $identity"
echo "built $(pwd)/Yap.app"
