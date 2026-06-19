# Contributing to BottleLite

Thanks for helping improve BottleLite. This is a native macOS app that runs
Windows executables through an existing Wine runtime. Changes should keep it
small, local-first, and runtime-agnostic — no bundled Wine, no telemetry, no
accounts.

## Good First Contributions

- Additional Wine runtime detection paths (other installers, MacPorts, custom builds).
- More one-click winetricks dependencies in `WinetricksVerb.common`.
- Accessibility, keyboard, and VoiceOver polish.
- Unit tests for `BottleStore`, `BottleRepository`, and `ExecutableInspector`.
- Documentation fixes that make installation or the Wine setup clearer.

## Development Setup

```bash
git clone https://github.com/jx-grxf/BottleLite.git
cd BottleLite
make build
make test
make run        # stages and launches dist/BottleLite.app
```

Requires macOS 14+ and a Swift 6 toolchain (Xcode 16+ or the matching command
line tools). Optional: `brew install --cask wine-stable` for runtime detection,
and `brew install winetricks` for the dependency installer.

Before opening a PR:

```bash
make lint       # swift-format lint + shellcheck
make test
```

## Pull Request Guidelines

- Keep PRs focused on one behavior or documentation area.
- Explain the user-facing impact and the validation you ran.
- Add or update tests when changing store, persistence, or validation behavior.
- No telemetry, network upload, account requirement, or bundled runtime without a
  dedicated design discussion first.
- No third-party SwiftPM dependency without a one-line justification of what it
  replaces — a hand-written 50-line file is almost always better than a new package.
- Match the existing style: SwiftUI views stay small, services sit behind
  protocols for testability, `@MainActor` on UI state, `swift-format` clean.

## Release Changes

Anything that affects packaging, the app bundle, versioning, or the Wine setup
flow should update `RELEASE_NOTES.md` and bump `VERSION` when appropriate.
