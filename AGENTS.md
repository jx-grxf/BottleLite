# BottleLite Agent Notes

- Keep the app native, small, and macOS-first. No Electron, no web shell.
- Prefer SwiftUI and SwiftPM until a real Xcode-only capability is required.
- Public-facing project text, commits, tags, issues, and releases are written in English.
- Do not vendor Wine, GPTK, or closed-source runtime components into this repository.
- Keep the first product promise narrow: import an `.exe`, create/manage bottles, run through an existing Wine runtime, and show useful logs.
