#!/usr/bin/env bash
# Regenerate every app icon artifact from the vector source.
#
# Source of truth: assets/bottlelite_icon.svg (rasterized to the 1024px PNG).
# If you only have a 1024px PNG, drop it in as assets/bottlelite_logo.png and the
# SVG rasterization step is skipped.
#
# Produces:
#   assets/bottlelite_logo.png             1024px master raster
#   assets/BottleLite.icns                 multi-resolution macOS icon (app bundle)
#   .github/assets/logo.png                256px README / GitHub logo
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SVG_SOURCE="assets/bottlelite_icon.svg"
SOURCE="assets/bottlelite_logo.png"
ICNS_OUT="assets/BottleLite.icns"
LOGO_OUT=".github/assets/logo.png"

# Rasterize the vector source to the 1024px master when present. Prefer
# Inkscape because Quick Look flattens SVG transparency to white on some macOS
# versions, which leaves a visible square behind the rounded app icon.
if [[ -f "$SVG_SOURCE" ]]; then
  if command -v inkscape >/dev/null 2>&1 && inkscape --version >/dev/null 2>&1; then
    inkscape "$SVG_SOURCE" \
      --export-type=png \
      --export-filename="$SOURCE" \
      --export-width=1024 \
      --export-height=1024 \
      --export-background-opacity=0 >/dev/null
    echo "Rasterized $SVG_SOURCE -> $SOURCE"
  else
    TMP_QL="$(mktemp -d)"
    trap 'rm -rf "$TMP_QL"' EXIT
    qlmanage -t -s 1024 -o "$TMP_QL" "$SVG_SOURCE" >/dev/null 2>&1
    rendered="$TMP_QL/$(basename "$SVG_SOURCE").png"
    if [[ -f "$rendered" ]]; then
      sips -z 1024 1024 "$rendered" --out "$SOURCE" >/dev/null
      python3 - "$SOURCE" <<'PY'
from PIL import Image, ImageDraw
import sys

path = sys.argv[1]
image = Image.open(path).convert("RGBA")
size = image.size[0]
scale = 4
mask = Image.new("L", (size * scale, size * scale), 0)
draw = ImageDraw.Draw(mask)
draw.rounded_rectangle(
    [40 * scale, 40 * scale, 984 * scale, 984 * scale],
    radius=232 * scale,
    fill=255,
)
mask = mask.resize(image.size, Image.Resampling.LANCZOS)
image.putalpha(mask)
image.save(path)
PY
      echo "Rasterized $SVG_SOURCE -> $SOURCE"
    fi
  fi
fi

if [[ ! -f "$SOURCE" ]]; then
  echo "error: missing source icon $SOURCE" >&2
  exit 1
fi

width="$(sips -g pixelWidth "$SOURCE" | awk '/pixelWidth/ {print $2}')"
if [[ "$width" -lt 1024 ]]; then
  echo "error: source icon must be at least 1024px wide (got ${width}px)" >&2
  exit 1
fi

ICONSET="$(mktemp -d)/BottleLite.iconset"
mkdir -p "$ICONSET"
trap 'rm -rf "$(dirname "$ICONSET")"' EXIT

clean_transparency() {
  python3 - "$@" <<'PY'
from PIL import Image
import sys

for path in sys.argv[1:]:
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha <= 4:
                pixels[x, y] = (0, 0, 0, 0)
    image.save(path)
PY
}

clean_transparency "$SOURCE"

# size:filename pairs for the standard macOS iconset.
render() {
  local size="$1" name="$2"
  sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/$name" >/dev/null
  clean_transparency "$ICONSET/$name"
}

render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

iconutil --convert icns "$ICONSET" --output "$ICNS_OUT"
echo "Wrote $ICNS_OUT"

mkdir -p "$(dirname "$LOGO_OUT")"
sips -z 256 256 "$SOURCE" --out "$LOGO_OUT" >/dev/null
clean_transparency "$LOGO_OUT"
echo "Wrote $LOGO_OUT"
