# Assets

## `bottlelite_icon.svg`

Vector source of truth for the app icon. Edit this, then run
`./script/make_icons.sh` to regenerate every raster artifact:

- `bottlelite_logo.png` — 1024px master raster (rasterized from the SVG)
- `BottleLite.icns` — multi-resolution macOS icon embedded in the app bundle
- `../.github/assets/logo.png` — 256px logo used in the README

If you already have a finished 1024×1024 PNG, drop it in as
`bottlelite_logo.png` and `make_icons.sh` will skip the SVG step and build the
`.icns` and README logo from it.

## `bottle-wine-lucide.svg`

Original base glyph: [Lucide `bottle-wine`](https://lucide.dev/icons/bottle-wine)
(ISC License, see the [Lucide repository](https://github.com/lucide-icons/lucide)).
Kept as a reference; the current icon is hand-authored in `bottlelite_icon.svg`.
