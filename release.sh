#!/bin/sh
# Builds Yap.zip for a GitHub release and points Casks/yap.rb at it.
# Notarises it when YAP_NOTARY_PROFILE names a notarytool keychain profile, which needs a
# Developer ID certificate. Without one, macOS refuses to open the app the cask installs.
set -e
cd "$(dirname "$0")"
./bundle.sh
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
rm -f Yap.zip
ditto -c -k --keepParent Yap.app Yap.zip
if [ -n "$YAP_NOTARY_PROFILE" ]; then
  xcrun notarytool submit Yap.zip --keychain-profile "$YAP_NOTARY_PROFILE" --wait
  xcrun stapler staple Yap.app
  rm Yap.zip && ditto -c -k --keepParent Yap.app Yap.zip # zip again, ticket included
else
  echo "not notarised: set YAP_NOTARY_PROFILE before publishing" >&2
fi
sum=$(shasum -a 256 Yap.zip | cut -d' ' -f1)
sed -i '' -e "s/^  version \".*\"/  version \"$version\"/" -e "s/^  sha256 .*/  sha256 \"$sum\"/" Casks/yap.rb
echo "built $(pwd)/Yap.zip ($version, $sum)"
echo "publish: gh release create v$version Yap.zip, then commit Casks/yap.rb"
