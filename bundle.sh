#!/bin/sh
# Builds Yap.app next to this script.
set -e
cd "$(dirname "$0")"
swift build -c release
rm -rf Yap.app && mkdir -p Yap.app/Contents/MacOS
cp .build/release/Yap Yap.app/Contents/MacOS/
cp Info.plist Yap.app/Contents/
mkdir -p Yap.app/Contents/Resources && cp icon/AppIcon.icns Yap.app/Contents/Resources/
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
