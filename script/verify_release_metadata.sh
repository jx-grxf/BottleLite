#!/usr/bin/env bash
# Validate release metadata without building the app.
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT_VERSION="$(tr -d '[:space:]' <VERSION)"
NOTES_VERSION="$(awk 'NR == 1 && $1 == "#" && $2 == "BottleLite" { print $3 }' RELEASE_NOTES.md)"

fail() {
  echo "error: $*" >&2
  exit 1
}

[[ "$PROJECT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$ ]] \
  || fail "VERSION '$PROJECT_VERSION' is not a supported semantic version"
[[ "$NOTES_VERSION" == "$PROJECT_VERSION" ]] \
  || fail "release notes version '$NOTES_VERSION' does not match VERSION '$PROJECT_VERSION'"

if [[ -n "${BOTTLELITE_VERSION:-}" && "$BOTTLELITE_VERSION" != "$PROJECT_VERSION" ]]; then
  fail "requested version '$BOTTLELITE_VERSION' does not match VERSION '$PROJECT_VERSION'"
fi
if [[ -n "${BOTTLELITE_BUILD:-}" && ! "$BOTTLELITE_BUILD" =~ ^[1-9][0-9]*$ ]]; then
  fail "release build '$BOTTLELITE_BUILD' must be a positive integer"
fi
if [[ -n "${BOTTLELITE_RELEASE_TAG:-}" && "$BOTTLELITE_RELEASE_TAG" != "v$PROJECT_VERSION" ]]; then
  fail "release tag '$BOTTLELITE_RELEASE_TAG' must equal 'v$PROJECT_VERSION'"
fi

case "${BOTTLELITE_UPDATE_CHANNEL:-}" in
  "") ;;
  stable)
    [[ "$PROJECT_VERSION" != *-* ]] || fail "stable releases cannot use a prerelease version"
    ;;
  beta)
    [[ "$PROJECT_VERSION" == *-beta.* ]] || fail "beta releases must use a -beta.N version"
    ;;
  *) fail "update channel must be stable or beta" ;;
esac

if [[ -f Package.resolved ]]; then
  python3 - <<'PY'
import json
from pathlib import Path

data = json.loads(Path("Package.resolved").read_text())
pins = data.get("pins", [])
sparkle = [pin for pin in pins if pin.get("identity") == "sparkle"]
if not sparkle:
    raise SystemExit("error: Package.resolved is missing Sparkle")
if not sparkle[0].get("state", {}).get("version"):
    raise SystemExit("error: Sparkle must be locked to a version")
PY
fi

echo "release metadata ok (version $PROJECT_VERSION)"
