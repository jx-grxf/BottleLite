#!/usr/bin/env bash
# Build the Sparkle ZIP + appcast for the current BottleLite release.
set -euo pipefail

cd "$(dirname "$0")/.."

: "${BOTTLELITE_VERSION:?BOTTLELITE_VERSION is required}"
: "${BOTTLELITE_SPARKLE_PRIVATE_KEY:?BOTTLELITE_SPARKLE_PRIVATE_KEY is required}"
: "${BOTTLELITE_SPARKLE_DOWNLOAD_PREFIX:?BOTTLELITE_SPARKLE_DOWNLOAD_PREFIX is required}"

CHANNEL="${BOTTLELITE_UPDATE_CHANNEL:-stable}"
BUILD="${BOTTLELITE_BUILD:-1}"

if [[ ! -d dist/BottleLite.app ]]; then
  echo "error: dist/BottleLite.app not found; run script/package_dmg.sh first" >&2
  exit 1
fi

mkdir -p dist/sparkle
ZIP="dist/sparkle/BottleLite-${BOTTLELITE_VERSION}.zip"
rm -f "$ZIP"

(cd dist && /usr/bin/ditto -c -k --sequesterRsrc --keepParent BottleLite.app "sparkle/BottleLite-${BOTTLELITE_VERSION}.zip")

find_sign_update() {
  local root sign
  for root in "$PWD/.build/artifacts" "$HOME/Library/Caches/org.swift.swiftpm/artifacts" "$HOME/Library/Developer/Xcode/DerivedData"; do
    [[ -d "$root" ]] || continue
    sign="$(find "$root" -type f -name sign_update 2>/dev/null | grep -v old_dsa_scripts | head -n 1 || true)"
    if [[ -n "$sign" ]]; then
      printf '%s' "$sign"
      return 0
    fi
  done
  return 1
}

SIGN_UPDATE="$(find_sign_update || true)"
if [[ -z "$SIGN_UPDATE" ]]; then
  echo "error: Sparkle EdDSA sign_update not found; run script/package_dmg.sh first" >&2
  exit 1
fi

KEY_FILE="$(mktemp)"
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s' "$BOTTLELITE_SPARKLE_PRIVATE_KEY" >"$KEY_FILE"

SIGNATURE_LINE="$("$SIGN_UPDATE" "$ZIP" -f "$KEY_FILE")"
ED_SIGNATURE="$(printf '%s' "$SIGNATURE_LINE" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
if [[ -z "$ED_SIGNATURE" ]]; then
  echo "error: could not parse edSignature from sign_update output" >&2
  exit 1
fi

LENGTH="$(stat -f%z "$ZIP")"
PUBDATE="$(LC_ALL=en_US date -u "+%a, %d %b %Y %H:%M:%S +0000")"
DOWNLOAD_URL="${BOTTLELITE_SPARKLE_DOWNLOAD_PREFIX%/}/BottleLite-${BOTTLELITE_VERSION}.zip"

DESCRIPTION_HTML=""
if [[ -f RELEASE_NOTES.md ]]; then
  DESCRIPTION_HTML="$(perl -0777 -ne '
    if (/^##[ ].*?\n(.*?)(?=^##[ ]|\z)/ms) {
      my $body = $1; my @out; my $inlist = 0;
      for my $line (split /\n/, $body) {
        if ($line =~ /^[-*]\s+(.+?)\s*$/) {
          my $t = $1;
          $t = $1 if $t =~ /^\*\*(.+?)\*\*/;
          $t =~ s/\s*[.:]\s*$//;
          $t =~ s/&/&amp;/g; $t =~ s/</&lt;/g; $t =~ s/>/&gt;/g;
          $t =~ s/`(.+?)`/<code>$1<\/code>/g;
          push @out, "<ul>" unless $inlist; $inlist = 1;
          push @out, "<li>$t</li>";
        }
      }
      push @out, "</ul>" if $inlist;
      print join("", @out);
    }
  ' RELEASE_NOTES.md)"
fi

DESCRIPTION_BLOCK=""
if [[ -n "$DESCRIPTION_HTML" ]]; then
  DESCRIPTION_BLOCK="      <description><![CDATA[${DESCRIPTION_HTML}]]></description>"
fi

CHANNEL_BLOCK=""
if [[ "$CHANNEL" != "stable" ]]; then
  CHANNEL_BLOCK="      <sparkle:channel>${CHANNEL}</sparkle:channel>"
fi

cat >dist/sparkle/appcast.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>BottleLite</title>
    <link>https://github.com/jx-grxf/BottleLite</link>
    <description>BottleLite ${CHANNEL} update feed</description>
    <language>en</language>
    <item>
      <title>BottleLite ${BOTTLELITE_VERSION}</title>
${DESCRIPTION_BLOCK}
${CHANNEL_BLOCK}
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${BOTTLELITE_VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <pubDate>${PUBDATE}</pubDate>
      <enclosure
        url="${DOWNLOAD_URL}"
        length="${LENGTH}"
        type="application/octet-stream"
        sparkle:edSignature="${ED_SIGNATURE}" />
    </item>
  </channel>
</rss>
EOF

echo "Wrote $ZIP"
echo "Wrote dist/sparkle/appcast.xml"
