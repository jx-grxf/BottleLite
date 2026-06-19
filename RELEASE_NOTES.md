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
  ad-hoc hardened-runtime build.

No telemetry, no account, no bundled runtime.

## Known Limitations

- Release builds are not yet Developer ID signed or notarized.
- The App Sandbox is not enabled (see SECURITY.md).
