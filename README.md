<p align="center">
  <h1 align="center">BottleLite</h1>
  <p align="center">A lightweight, open-source macOS runner for Windows apps.</p>
</p>

<p align="center">
  <a href="https://github.com/johannesgrof/BottleLite/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/johannesgrof/BottleLite/ci.yml?branch=main&style=flat-square&label=CI"></a>
  <a href="https://github.com/johannesgrof/BottleLite/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/github/license/johannesgrof/BottleLite?style=flat-square"></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-111827?style=flat-square&logo=apple">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white">
  <img alt="Native" src="https://img.shields.io/badge/native-SwiftUI-0A84FF?style=flat-square">
  <img alt="Telemetry" src="https://img.shields.io/badge/telemetry-none-16A34A?style=flat-square">
</p>

BottleLite is an indie macOS app for running Windows `.exe` files through an
existing Wine runtime without turning the experience into a heavy launcher.

It is intentionally small: native SwiftUI, no Electron, no accounts, no cloud,
no telemetry, and no bundled proprietary runtime.

## Why

Most Wine frontends are either powerful but busy, game-first, or tied to large
runtime assumptions. BottleLite aims for the opposite:

- Pick or drop an `.exe`.
- Keep it inside a simple bottle.
- Show what is installed, what is missing, and where logs live.
- Stay understandable enough that contributors can improve it without learning
  a giant launcher architecture first.

## Current Status

BottleLite is an early prototype. The current app shell can:

- create lightweight bottle records
- import and validate Windows executables by extension and `MZ` header
- detect a local Homebrew Wine runtime
- launch as a real macOS `.app` bundle from SwiftPM
- run tests in CI

Running programs through Wine is the next implementation milestone.

## Design Principles

- **Mac-native first**: SwiftUI windows, toolbars, menus, settings, and system
  materials.
- **Fast by default**: small state model, no embedded browser, no background
  services.
- **Runtime-agnostic**: detect existing Wine builds first; do not vendor closed
  runtime components into the repo.
- **Honest diagnostics**: show missing Wine, invalid EXE files, and launch logs
  clearly.
- **Hackable**: SwiftPM package, one build script, readable modules.

## Requirements

- macOS 14 or newer
- Xcode command line tools or Xcode
- Swift 6 compatible toolchain
- Optional: Wine installed with Homebrew for runtime detection

```bash
brew install --cask wine-stable
```

## Build

```bash
git clone https://github.com/johannesgrof/BottleLite.git
cd BottleLite
make build
make test
```

## Run

BottleLite is a SwiftPM GUI app. Use the project script so it is staged and
opened as a real macOS app bundle:

```bash
make run
```

The app bundle is written to:

```text
dist/BottleLite.app
```

## Repository Layout

```text
Sources/BottleLite/
  App/        App entry point and macOS activation
  Models/     Bottle and program data types
  Stores/     App state
  Services/   EXE validation and Wine runtime probing
  Views/      SwiftUI windows and panels
  Support/    Small shared helpers
script/       Build and run entrypoint
Tests/        Swift Testing tests
```

## Roadmap

- Run imported `.exe` files through Wine.
- Create real per-bottle Wine prefixes.
- Add bottle folders under Application Support.
- Show launch logs inside the app.
- Add Winetricks/runtime helper checks.
- Add a lightweight `.app` wrapper export.
- Package signed builds for releases.

## Non-Goals

- Reimplementing Wine.
- Bundling Apple Game Porting Toolkit files.
- Becoming a full game launcher.
- Tracking users or phoning home.

## License

MIT. See [LICENSE](LICENSE).
