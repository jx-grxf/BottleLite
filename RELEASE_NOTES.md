# BottleLite 0.2.0

Gaming and runtime release: better Steam, smarter Wine selection, and a batch of
launch-reliability fixes.

## Highlights

- **Per-bottle Wine runtime.** Each bottle can now pick its own Wine binary
  (Bottle Settings → Wine Runtime). Game Porting Toolkit stays the default for
  modern/DirectX games, but 32-bit and OpenGL titles that GPTK can't run (e.g.
  AssaultCube — `alloc_pages_vprot` crash) can be pinned to a plain Wine. The
  picker lists every detected Wine and offers to install one when only GPTK is
  present.
- **Steam launch hardening.** One-click Steam now requires a gaming-grade Wine
  before installing, creates its bottle from the tuned Steam template (Game Mode +
  fastest graphics), and only applies the 32-bit CEF workaround once Steam has
  bootstrapped — so it can't block the first launch.
- **Shortcut parity.** Generated `.app` launchers now use the exact same
  environment (graphics-backend DLL overrides, Game Mode, library paths) and
  injected arguments as launching inside BottleLite, so a program behaves the same
  either way.

## Fixes

- Stopping a single program now tears down its Wine prefix (no orphaned helpers),
  while leaving sibling programs in the same bottle running.
- DXVK can no longer be installed or suggested on a Game Porting Toolkit Wine,
  where the arm64 MoltenVK can't load — D3DMetal is offered instead.
- `Prepare Bottle` surfaces `wineboot` failures instead of silently reporting
  success.
- `Game Mode` no longer sets `WINE_LARGE_ADDRESS_AWARE` on a GPTK Wine, where it
  is a no-op for 64-bit apps and can crash 32-bit games.
- The Wine version is cached, so launching a program no longer blocks the UI on a
  `wine --version` subprocess.
- Clearer status messages (relaunch the program, not the app, after a graphics or
  DXVK change).

# BottleLite 0.1.1

Packaging-only update for the first preview release.

## Changes

- Release DMGs now use a styled drag-to-Applications layout built with
  `create-dmg`, including persisted Finder geometry, a volume icon, hidden app
  extension, and a positioned Applications drop link.
- CI and the GitHub Release workflow now install `create-dmg` and fail if the
  styled DMG path falls back to a plain `hdiutil` image.

# BottleLite 0.1.0

First tagged preview of BottleLite — a lightweight, native macOS runner for
Windows apps on top of an existing Wine runtime.

## Highlights

- **Bottles that persist.** Create, rename, and delete bottles; records and
  imported programs are saved to Application Support and restored on launch.
  Deleting a bottle moves its Wine prefix to the Trash.
- **Import and validate.** Drop or pick an `.exe`; BottleLite checks the
  extension and `MZ` header and keeps each program inside its bottle.
- **Run through Wine.** Launch and stop programs, with the detected Wine version
  shown in the header. Each launch captures stdout/stderr to a per-program log
  you can open from the app.
- **Console tools in Terminal.** Windows console/CUI tools are detected from the
  PE subsystem and opened in Terminal.app so output and prompts are visible. The
  setting can be overridden per program.
- **Installer → game flow.** Run an installer in the bottle, then **Add Installed
  Program** scans the prefix's C: drive and lets you add the actual game/app it
  dropped (skipping uninstallers and redistributables) — or browse C: manually.
- **Game Mode.** A per-bottle switch for extra performance: msync/esync,
  large-address-aware, higher process priority, a macOS power assertion (no App
  Nap / no idle sleep), and the Metal FPS overlay.
- **Per-bottle tooling.** Initialize the prefix (`wineboot`), open `winecfg`,
  run an installer, reveal the C: drive in Finder, and install common
  dependencies via winetricks (.NET, Visual C++, corefonts, DXVK).
- **Native macOS.** SwiftUI sidebar/detail layout, menu commands and keyboard
  shortcuts, a Settings window, a proper multi-resolution app icon, and an
  ad-hoc signed preview build.
- **Sparkle updates.** Stable and beta channels are wired through signed Sparkle
  appcasts; beta builds publish a moving beta feed.
- **Release artifact.** The DMG is built from an optimized release binary and is
  published with a Sparkle ZIP, appcast, and SHA-256 checksums.

No telemetry, no account, no bundled runtime.

## Known Limitations

- Preview builds are ad-hoc signed, but not yet Developer ID signed or notarized.
- The App Sandbox is not enabled (see SECURITY.md).
- BottleLite depends on an existing local Wine runtime and does not guarantee
  compatibility for every Windows application.
