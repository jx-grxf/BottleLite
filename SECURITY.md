# Security Policy

BottleLite runs entirely on the local machine. It does not send telemetry,
analytics, or any data anywhere, and it does not require an account. The trust
boundaries that matter are: the integrity of the downloaded app bundle, the
detection and invocation of an existing Wine runtime, and the execution of
user-imported Windows executables through that runtime.

## Reporting a Vulnerability

Report security issues through GitHub:

- **Preferred — private report:** open the repository's **Security** tab and
  choose **“Report a vulnerability”** (GitHub private vulnerability reporting).
  This keeps the details confidential until a fix ships.
- **Otherwise — open an issue:** if private reporting is unavailable to you, open
  a [GitHub issue](https://github.com/jx-grxf/BottleLite/issues). Describe the
  impact but **do not include a working exploit or sensitive details** in the
  public thread — note that you have them and they will be requested privately.

A response within 72 hours is the target. If a fix ships, the release notes will
credit the reporter unless they request otherwise.

## Scope

In scope:

- Arbitrary code execution outside the intended Wine sandboxing model via a
  crafted executable, bottle record, or persisted `bottles.json`.
- Command injection through the Terminal helper scripts (Wine install, winetricks).
- Path traversal or symlink escapes during import, prefix creation, or the
  move-to-Trash on bottle deletion.
- Wine runtime path detection being tricked into launching an attacker-controlled
  binary.
- Tampering with the release DMG or its signature.

Out of scope (for now):

- Vulnerabilities inside Wine, winetricks, or the Windows software being run —
  BottleLite is a launcher, not the runtime. Report those upstream.
- Issues that require root or physical access.
- The inherent risk of running untrusted Windows `.exe` files: BottleLite
  validates the `MZ` header and isolates each bottle in its own prefix, but a
  Windows executable you choose to run is still arbitrary code on your machine.

## Hardening

- Local builds are ad-hoc signed with the hardened runtime
  (`codesign --options runtime`); release builds will use Developer ID signing
  and notarization once Apple Developer enrollment lands.
- No bundled Wine, GPTK, or closed-source runtime components.
- Each bottle runs in its own `WINEPREFIX` under
  `~/Library/Application Support/BottleLite/Bottles/<id>` — deleting a bottle
  moves that prefix to the Trash; `rm -rf ~/Library/Application Support/BottleLite`
  removes every trace.
- Wine subprocesses run with `WINEDEBUG=-all` and a PATH scoped to the detected
  Wine binary's directory; stdout/stderr are captured to per-launch log files,
  not streamed anywhere off-device.

## App Sandbox

Not currently enabled: the app must launch user-chosen executables through Wine,
which spawns helper processes and writes prefixes outside a container. Enabling
App Sandbox with `com.apple.security.files.user-selected.read-write` plus
security-scoped bookmarks is tracked for a future release once the run pipeline
is auditable under the sandbox.
