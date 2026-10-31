#!/bin/sh
# Builds, signs, notarizes and packages BonjourView for a GitHub release.
# Produces build/release/BonjourView-<version>.zip, .dmg and SHA256SUMS.txt.
# The asset names must stay ^BonjourView-[0-9.]+\.(zip|dmg)$: the AutoPkg
# recipes at github.com/hov172/autopkg-recipes match on that pattern.
#
# Usage: scripts/release.sh
# Notarization credentials, one of:
#   NOTARY_PROFILE                       name of an `xcrun notarytool store-credentials` profile
#   NOTARY_APPLE_ID NOTARY_PASSWORD      Apple ID and app-specific password (team from DEVELOPMENT_TEAM.xcconfig)
set -eu
cd "$(dirname "$0")/.."

VERSION="$(sed -n 's/^BONJOURVIEW_SHORT_VERSION = //p' Shared.xcconfig)"
[ -n "$VERSION" ] || { echo "BONJOURVIEW_SHORT_VERSION missing from Shared.xcconfig" >&2; exit 1; }
TEAM_ID="$(sed -n 's/^DEVELOPMENT_TEAM = //p' DEVELOPMENT_TEAM.xcconfig 2>/dev/null || true)"
[ -n "$TEAM_ID" ] || { echo "DEVELOPMENT_TEAM.xcconfig missing (see Base.xcconfig)" >&2; exit 1; }

if [ -n "${NOTARY_PROFILE:-}" ]; then
	set -- --keychain-profile "$NOTARY_PROFILE"
elif [ -n "${NOTARY_APPLE_ID:-}" ] && [ -n "${NOTARY_PASSWORD:-}" ]; then
	set -- --apple-id "$NOTARY_APPLE_ID" --password "$NOTARY_PASSWORD" --team-id "$TEAM_ID"
else
	echo "Set NOTARY_PROFILE, or NOTARY_APPLE_ID and NOTARY_PASSWORD" >&2; exit 1
fi

OUT="build/release"
NAME="BonjourView-$VERSION"
ARCHIVE="build/BonjourView.xcarchive"
APP="$ARCHIVE/Products/Applications/BonjourView.app"
rm -rf "$OUT" "$ARCHIVE"
mkdir -p "$OUT"

xcodebuild archive -quiet \
	-project BonjourView.xcodeproj -scheme BonjourView -configuration Release \
	-archivePath "$ARCHIVE" \
	CODE_SIGN_IDENTITY="Developer ID Application" CODE_SIGN_STYLE=Manual

# Notarize the app, then staple it before it goes into the zip and the disk image.
ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
xcrun notarytool submit "$OUT/notarize.zip" "$@" --wait
xcrun stapler staple "$APP"
rm "$OUT/notarize.zip"
ditto -c -k --keepParent "$APP" "$OUT/$NAME.zip"

STAGING="$OUT/dmg"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -quiet -volname BonjourView -srcfolder "$STAGING" -format UDZO "$OUT/$NAME.dmg"
rm -r "$STAGING"
codesign --sign "Developer ID Application" --timestamp "$OUT/$NAME.dmg"
xcrun notarytool submit "$OUT/$NAME.dmg" "$@" --wait
xcrun stapler staple "$OUT/$NAME.dmg"

(cd "$OUT" && shasum -a 256 "$NAME.zip" "$NAME.dmg" | tee SHA256SUMS.txt)
echo "Release $VERSION assets are in $OUT. Publish with:"
echo "  git tag v$VERSION && git push origin v$VERSION"
echo "  gh release create v$VERSION --title 'BonjourView $VERSION' --generate-notes --notes-file $OUT/SHA256SUMS.txt $OUT/$NAME.dmg $OUT/$NAME.zip"
