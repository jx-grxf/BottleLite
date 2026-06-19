# Release Runbook

End-to-end procedure for cutting a BottleLite release.

## Channels

- **stable** — tags like `v0.1.0`. Published as the latest GitHub Release. Sparkle reads `releases/latest/download/appcast.xml`.
- **beta** — tags like `v0.2.0-beta.1`. Published as a GitHub prerelease and mirrored to the moving `beta` release as `appcast.xml`.

Stable appcast items do not carry a Sparkle channel tag. Beta items carry `sparkle:channel=beta`.

## Prerequisites

1. Sparkle public key is embedded in `script/build_and_run.sh` as `SUPublicEDKey`.
2. Sparkle private key is stored as GitHub secret `BOTTLELITE_SPARKLE_PRIVATE_KEY`.
3. Current preview builds are ad-hoc signed. Users must right-click the app and choose Open on first launch.
4. Later Developer ID releases can set `BOTTLELITE_SIGN_IDENTITY` and notarization secrets.

## Per-Release Checklist

1. Update `VERSION` and `RELEASE_NOTES.md`.
2. Run local gates:
   ```bash
   make lint
   make test
   make package
   ```
3. Merge to `main`.
4. Tag from `main` with a signed annotated tag:
   ```bash
   git checkout main
   git pull
   git tag -s v0.1.0 -m "BottleLite 0.1.0"
   git push origin v0.1.0
   ```
5. The release workflow verifies the signed tag, tests the tagged source, builds a styled `create-dmg` drag-install DMG, signs the Sparkle ZIP/appcast, optionally notarizes, publishes GitHub Release assets, and verifies the published release.

## Rollback

If a release is broken, delete or unpublish the GitHub Release, then ship a higher version. Do not force-push an already-published tag.
