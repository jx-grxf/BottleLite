#!/usr/bin/env bash
# Build BottleLite and package it into a distributable DMG.
#
#   ./script/package_dmg.sh                 # version from VERSION file
#   BOTTLELITE_VERSION=0.2.0 ./script/package_dmg.sh
#
# Output: dist/BottleLite-<version>.dmg
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

APP_NAME="BottleLite"
VERSION="${BOTTLELITE_VERSION:-$(tr -d '[:space:]' <VERSION)}"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

# Build and stage an optimized app bundle (no launch).
BOTTLELITE_VERSION="$VERSION" BOTTLELITE_CONFIGURATION=release ./script/build_and_run.sh build-only

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "error: $APP_BUNDLE was not produced" >&2
  exit 1
fi

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$STAGING" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$DMG_PATH" >/dev/null

echo "Built $DMG_PATH"
hdiutil imageinfo "$DMG_PATH" >/dev/null && echo "DMG verified."
shasum -a 256 "$DMG_PATH" >"$DMG_PATH.sha256"
echo "Wrote $DMG_PATH.sha256"
