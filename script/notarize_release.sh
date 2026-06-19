#!/usr/bin/env bash
# Submit dist/BottleLite-<version>.dmg for Apple notarization when configured.
set -euo pipefail

cd "$(dirname "$0")/.."

: "${BOTTLELITE_VERSION:?BOTTLELITE_VERSION is required}"

if [[ "${BOTTLELITE_NOTARY_ENABLED:-}" != "true" ]]; then
  echo "Notarization skipped (BOTTLELITE_NOTARY_ENABLED != true; ad-hoc preview)"
  exit 0
fi

DMG="dist/BottleLite-${BOTTLELITE_VERSION}.dmg"
[[ -f "$DMG" ]] || { echo "error: $DMG not found" >&2; exit 1; }

if [[ -n "${BOTTLELITE_NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG" \
    --keychain-profile "$BOTTLELITE_NOTARY_KEYCHAIN_PROFILE" \
    --wait
else
  : "${BOTTLELITE_NOTARY_APPLE_ID:?required}"
  : "${BOTTLELITE_NOTARY_TEAM_ID:?required}"
  : "${BOTTLELITE_NOTARY_PASSWORD:?required}"
  xcrun notarytool submit "$DMG" \
    --apple-id "$BOTTLELITE_NOTARY_APPLE_ID" \
    --team-id "$BOTTLELITE_NOTARY_TEAM_ID" \
    --password "$BOTTLELITE_NOTARY_PASSWORD" \
    --wait
fi

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
