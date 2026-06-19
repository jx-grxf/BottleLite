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
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/assets/BottleLite.icns"
ICON_NAME="BottleLite.icns"

cd "$ROOT_DIR"

# Version metadata: marketing version from the VERSION file, build number from
# the git commit count so each commit produces a monotonically rising build.
APP_VERSION="${BOTTLELITE_VERSION:-$(tr -d '[:space:]' <VERSION 2>/dev/null || echo 0.0.0)}"
APP_BUILD="${BOTTLELITE_BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
CONFIGURATION="${BOTTLELITE_CONFIGURATION:-debug}"
BOTTLELITE_SPARKLE_PUBLIC_KEY="${BOTTLELITE_SPARKLE_PUBLIC_KEY:-mfMTRb7wc/RmaJckwKlm+ESCHKDp75q5WHJYRxWddnU=}"
BOTTLELITE_SIGN_IDENTITY="${BOTTLELITE_SIGN_IDENTITY:--}"
COPYRIGHT="Copyright © $(date +%Y) Johannes Grof. MIT licensed."

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

case "$CONFIGURATION" in
  debug)
    swift build
    BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"
    ;;
  release)
    swift build -c release
    BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"
    ;;
  *)
    echo "error: BOTTLELITE_CONFIGURATION must be 'debug' or 'release'" >&2
    exit 2
    ;;
esac

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_FRAMEWORKS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

find_sparkle_framework() {
  local root framework
  for root in "$ROOT_DIR/.build/artifacts" "$HOME/Library/Caches/org.swift.swiftpm/artifacts"; do
    [[ -d "$root" ]] || continue
    framework="$(find "$root" -type d -name Sparkle.framework 2>/dev/null | head -n 1 || true)"
    if [[ -n "$framework" ]]; then
      printf '%s' "$framework"
      return 0
    fi
  done
  return 1
}

SPARKLE_FRAMEWORK="$(find_sparkle_framework || true)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  echo "error: Sparkle.framework was not found after swift build" >&2
  exit 1
fi
cp -R "$SPARKLE_FRAMEWORK" "$APP_FRAMEWORKS/"

if ! otool -l "$APP_BINARY" | grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BINARY"
fi

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
  <key>SUFeedURL</key>
  <string>https://github.com/jx-grxf/BottleLite/releases/latest/download/appcast.xml</string>
  <key>SUPublicEDKey</key>
  <string>$BOTTLELITE_SPARKLE_PUBLIC_KEY</string>
  <key>SUEnableInstallerLauncherService</key>
  <true/>
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUScheduledCheckInterval</key>
  <integer>3600</integer>
</dict>
</plist>
PLIST

# Ad-hoc preview signing is intentionally not hardened: Hardened Runtime's
# library validation rejects Sparkle's pre-signed framework unless a real
# Developer ID identity is used. When BOTTLELITE_SIGN_IDENTITY is configured,
# use Hardened Runtime so the same script is notarization-ready.
SIGN_ARGS=(--force --sign "$BOTTLELITE_SIGN_IDENTITY" --timestamp=none)
if [[ "$BOTTLELITE_SIGN_IDENTITY" != "-" ]]; then
  SIGN_ARGS+=(--options runtime)
fi
codesign "${SIGN_ARGS[@]}" "$APP_FRAMEWORKS/Sparkle.framework" >/dev/null
codesign "${SIGN_ARGS[@]}" "$APP_BUNDLE" >/dev/null

echo "Built $APP_BUNDLE ($APP_VERSION build $APP_BUILD, $CONFIGURATION)"

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
