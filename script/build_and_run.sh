#!/usr/bin/env bash
# Build the BottleLite SwiftPM binary, stage it into a real .app bundle, and
# (optionally) launch it.
#
# Usage:
#   ./script/build_and_run.sh              # build + launch
#   ./script/build_and_run.sh build-only   # build + stage bundle, do not launch
#   ./script/build_and_run.sh --debug      # build + attach lldb
#   ./script/build_and_run.sh --logs       # build + launch + stream os_log
#   ./script/build_and_run.sh --verify     # build + launch + assert it is running
set -euo pipefail

MODE="${1:-run}"
APP_NAME="BottleLite"
BUNDLE_ID="dev.johannesgrof.BottleLite"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/assets/BottleLite.icns"
ICON_NAME="BottleLite.icns"

cd "$ROOT_DIR"

# Version metadata: marketing version from the VERSION file, build number from
# the git commit count so each commit produces a monotonically rising build.
APP_VERSION="${BOTTLELITE_VERSION:-$(tr -d '[:space:]' <VERSION 2>/dev/null || echo 0.0.0)}"
APP_BUILD="${BOTTLELITE_BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
COPYRIGHT="Copyright © $(date +%Y) Johannes Grof. MIT licensed."

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$APP_RESOURCES/$ICON_NAME"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHumanReadableCopyright</key>
  <string>$COPYRIGHT</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign with the hardened runtime so local builds behave like a release
# build (Gatekeeper, library validation). Real Developer ID signing happens in
# the release pipeline.
codesign --force --sign - --options runtime --timestamp=none "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "Built $APP_BUNDLE ($APP_VERSION build $APP_BUILD)"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  build-only)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|build-only|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
