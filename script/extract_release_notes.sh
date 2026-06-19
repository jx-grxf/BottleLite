#!/usr/bin/env bash
# Extract BottleLite's current release notes into a GitHub release body.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?usage: extract_release_notes.sh VERSION OUTPUT}"
OUTPUT="${2:?usage: extract_release_notes.sh VERSION OUTPUT}"

awk -v version="$VERSION" '
  NR == 1 && $1 == "#" && $2 == "BottleLite" && $3 == version { found = 1 }
  found { print }
  END { if (!found) exit 1 }
' RELEASE_NOTES.md >"$OUTPUT"

[[ -s "$OUTPUT" ]] || { echo "error: release notes for $VERSION are empty" >&2; exit 1; }
