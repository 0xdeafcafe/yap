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
codesign --force --options runtime --entitlements Yap.entitlements --sign "$identity" Yap.app
echo "signed with: $identity"
echo "built $(pwd)/Yap.app"
