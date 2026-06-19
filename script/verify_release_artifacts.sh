#!/usr/bin/env bash
# Validate every distributable before publishing and write SHA256SUMS.
set -euo pipefail

cd "$(dirname "$0")/.."

: "${BOTTLELITE_VERSION:?BOTTLELITE_VERSION is required}"
: "${BOTTLELITE_BUILD:?BOTTLELITE_BUILD is required}"
: "${BOTTLELITE_UPDATE_CHANNEL:?BOTTLELITE_UPDATE_CHANNEL is required}"
: "${BOTTLELITE_RELEASE_TAG:?BOTTLELITE_RELEASE_TAG is required}"

APP="dist/BottleLite.app"
DMG="dist/BottleLite-${BOTTLELITE_VERSION}.dmg"
ZIP="dist/sparkle/BottleLite-${BOTTLELITE_VERSION}.zip"
APPCAST="dist/sparkle/appcast.xml"

for path in "$APP" "$DMG" "$ZIP" "$APPCAST"; do
  [[ -e "$path" ]] || { echo "error: release artifact missing: $path" >&2; exit 1; }
done

INFO="$APP/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO")" == "dev.johannesgrof.BottleLite" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO")" == "$BOTTLELITE_VERSION" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO")" == "$BOTTLELITE_BUILD" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$INFO")" == "https://github.com/jx-grxf/BottleLite/releases/latest/download/appcast.xml" ]]
[[ -n "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$INFO")" ]]

codesign --verify --deep --strict "$APP"
lipo -archs "$APP/Contents/MacOS/BottleLite" | grep -qw arm64
hdiutil imageinfo "$DMG" >/dev/null
unzip -tq "$ZIP" >/dev/null

./script/verify_appcast.swift \
  "$APPCAST" \
  "https://github.com/${GITHUB_REPOSITORY:-jx-grxf/BottleLite}/releases/download/${BOTTLELITE_RELEASE_TAG}/BottleLite-${BOTTLELITE_VERSION}.zip" \
  "$BOTTLELITE_UPDATE_CHANNEL" \
  "$BOTTLELITE_VERSION" \
  "$BOTTLELITE_BUILD" \
  "$ZIP"

if [[ "${BOTTLELITE_NOTARY_ENABLED:-}" == "true" ]]; then
  xcrun stapler validate "$DMG"
fi

(
  cd dist
  shasum -a 256 "BottleLite-${BOTTLELITE_VERSION}.dmg"
  shasum -a 256 "sparkle/BottleLite-${BOTTLELITE_VERSION}.zip" | sed 's#  sparkle/#  #'
  shasum -a 256 "sparkle/appcast.xml" | sed 's#  sparkle/#  #'
) >dist/SHA256SUMS

echo "release artifacts ok"
