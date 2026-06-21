# BottleLite — Agent Guide

Native, MIT-licensed macOS app (SwiftPM, swift-tools 6.0, Swift 6 strict
concurrency, deployment target macOS 14) for running Windows apps and games through
Wine — a "Whisky-style" bottle manager. Each Windows app lives in its own isolated
Wine prefix ("bottle"). It is a maintained open-source alternative to Whisky, NOT a
CrossOver replacement: it does not vendor Wine, GPTK, or closed-source runtime
components — it detects/installs and orchestrates the user's runtime.

## Read first: the project brain

Deep, linked project knowledge lives in the Obsidian vault under `Brain/`.
Entry point: `Brain/00_Index/Start Here.md`.

Brain working rules:

- Before broad research, check `Brain/` before grepping the code wide.
- On new features, refactors, releases, and bugfixes, update the relevant notes or
  add new ones linked with `[[wikilinks]]`.
- Fix stale notes instead of creating duplicates.
- `Brain/` and `CLAUDE.md` are local agent context and are not versioned
  (`.gitignore`). `AGENTS.md` is the committed, public agent guide.

## Build & Run

```bash
make build      # swift build
make test       # swift test
make run        # ./script/build_and_run.sh
make lint       # swift-format lint --strict + shellcheck
make package    # ./script/package_dmg.sh
```

- SwiftPM project (`Package.swift`); no Xcode project, no xcodegen.
- `VERSION` holds the marketing version. Single dependency: Sparkle exact `2.9.3`.
- `make lint` is strict (`.swift-format`); warnings fail.

## Architecture (brief)

`BottleLiteApp` hosts a `WindowGroup` + `Settings` and an `AppDelegate`. The whole UI
observes one `@MainActor ObservableObject`, `BottleStore` (`Stores/`), which owns the
bottles and every user action. Services are behind protocols injected into
`BottleStore.init` (runtime probe, program runner, installers, tooling, repository),
so the test target runs without a real Wine. On-disk paths are centralized in
`Support/BottleStorage.swift`. See `Brain/10_Architektur/`.

## What-where

| Change | File |
|---|---|
| Central state / any user action | `Stores/BottleStore.swift` |
| Program launch / Game Mode env | `Services/WineProgramRunner.swift` |
| Wine binary selection | `Services/WineRuntimeProbe.swift` |
| Graphics backend (overrides, detection) | `Models/GraphicsBackend.swift` + `Services/GamingRuntime.swift` |
| DXVK download/install | `Services/DXVKInstaller.swift` |
| winecfg / winetricks / installers / teardown | `Services/BottleTooling.swift` |
| Native `.app` launcher + icon | `Services/ShortcutBuilder.swift` + `Services/ExecutableIconExtractor.swift` |
| Wine / GPTK / MoltenVK install | `Services/WineInstaller.swift` |
| On-disk paths | `Support/BottleStorage.swift` |
| Sparkle / updates | `Updates/UpdateService.swift` |
| Build/CI/release | `Package.swift`, `Makefile`, `.github/workflows/`, `script/` |

## Critical invariants

- Keep gaming-grade Wine (GPTK / CrossOver lineage) preferred over plain Wine —
  stock `wine-stable` can't run the modern Steam client.
- Never offer DXVK on a GPTK (x86) Wine; arm64 MoltenVK can't load there — route to
  D3DMetal. D3DMetal override is builtin-only (`=b`), never native-first.
- MoltenVK lives under `etc/` and `lib/`, not `share/`.
- `rc=$?`, never `status=$?`, in any zsh `.command` the app emits.
- Set `WINE`/`WINE64` in the tooling env (GPTK ships only `wine64`).
- Tear down Wine on quit/stop (`wineserver -k` per active prefix).
- Releases build on `macos-26` (Liquid Glass / macOS 26 SDK); deployment target
  stays macOS 14. Keep the CI `build` aggregate gate.

These are detailed with symptom → cause → fix in `Brain/40_Pitfalls/`.

## Work conventions

- English only — all communication, PRs, commits, branch names, release notes,
  issue text, and docs.
- Check branch and status before persistent code changes.
- No tool/author traces in commits, branch names, PR text, or code comments. Name
  branches by content.
- Respect the existing store-centric design and the protocol-injection test seams;
  keep changes scoped — no unrelated refactors.
- Keep the first product promise narrow: import an `.exe`, create/manage bottles,
  run through an existing Wine runtime, show useful logs.
- Do not vendor Wine, GPTK, or closed-source runtime components into this repository.
- Any git-running automation must operate in an isolated git worktree, never the
  main tree.
