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
REQUIRE_STYLED_DMG="${BOTTLELITE_REQUIRE_STYLED_DMG:-false}"

# Prefer the Homebrew create-dmg/create-dmg tool because it can persist Finder
# window geometry and app-drop-link layout. The npm package with the same name
# has a different CLI, so keep it as a weaker fallback for local packaging.
CREATE_DMG_BIN=""
for candidate in \
  "/opt/homebrew/opt/create-dmg/bin/create-dmg" \
  "/usr/local/opt/create-dmg/bin/create-dmg" \
  "/opt/homebrew/bin/create-dmg" \
  "/usr/local/bin/create-dmg" \
  "$(command -v create-dmg 2>/dev/null || true)"; do
  [[ -z "$candidate" || ! -x "$candidate" ]] && continue
  if "$candidate" --help 2>&1 | grep -q -- "--volname"; then
    CREATE_DMG_BIN="$candidate"
    break
  fi
done
if [[ -z "$CREATE_DMG_BIN" ]]; then
  CREATE_DMG_BIN="$(command -v create-dmg 2>/dev/null || true)"
fi

# Build and stage an optimized app bundle (no launch).
BOTTLELITE_VERSION="$VERSION" BOTTLELITE_CONFIGURATION=release ./script/build_and_run.sh build-only

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "error: $APP_BUNDLE was not produced" >&2
  exit 1
fi

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

rm -f "$DMG_PATH"

build_plain_dmg() {
  if [[ "$REQUIRE_STYLED_DMG" == "true" ]]; then
    echo "error: styled DMG is required but create-dmg was unavailable or failed" >&2
    exit 1
  fi

  echo "note: building a plain DMG via hdiutil" >&2
  rm -rf "$STAGING"
  mkdir -p "$STAGING"
  cp -R "$APP_BUNDLE" "$STAGING/"
  ln -s /Applications "$STAGING/Applications"
  hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG_PATH" >/dev/null
}

CREATE_DMG_HELP=""
[[ -n "$CREATE_DMG_BIN" ]] && CREATE_DMG_HELP="$("$CREATE_DMG_BIN" --help 2>&1 || true)"

if [[ "$CREATE_DMG_HELP" == *"--volname"* ]]; then
  cp -R "$APP_BUNDLE" "$STAGING/"
  if ! "$CREATE_DMG_BIN" \
      --volname "$APP_NAME $VERSION" \
      --volicon "assets/BottleLite.icns" \
      --window-pos 200 120 \
      --window-size 620 390 \
      --text-size 13 \
      --icon-size 112 \
      --icon "$APP_NAME.app" 175 205 \
      --app-drop-link 445 205 \
      --hide-extension "$APP_NAME.app" \
      --no-internet-enable \
      --format UDZO \
      "$DMG_PATH" \
      "$STAGING" >/dev/null; then
    echo "warning: styled create-dmg failed; falling back to a plain DMG" >&2
    rm -f "$DMG_PATH"
    build_plain_dmg
  fi
elif [[ "$CREATE_DMG_HELP" == *"--dmg-title"* ]]; then
  if [[ "$REQUIRE_STYLED_DMG" == "true" ]]; then
    echo "error: styled Homebrew create-dmg is required; found npm create-dmg instead" >&2
    exit 1
  fi

  find "$DIST_DIR" -maxdepth 1 -type f -name "$APP_NAME*.dmg" -delete
  (
    cd "$DIST_DIR"
    "$CREATE_DMG_BIN" --overwrite --no-code-sign \
      --dmg-title="$APP_NAME $VERSION" "$APP_NAME.app" . >/dev/null 2>&1 || true
  )
  produced="$(find "$DIST_DIR" -maxdepth 1 -type f -name "$APP_NAME*.dmg" -print -quit)"
  if [[ -n "$produced" && "$produced" != "$DMG_PATH" ]]; then
    mv "$produced" "$DMG_PATH"
  fi
  [[ -f "$DMG_PATH" ]] || build_plain_dmg
else
  build_plain_dmg
fi

echo "Built $DMG_PATH"
hdiutil imageinfo "$DMG_PATH" >/dev/null && echo "DMG verified."
shasum -a 256 "$DMG_PATH" >"$DMG_PATH.sha256"
echo "Wrote $DMG_PATH.sha256"
