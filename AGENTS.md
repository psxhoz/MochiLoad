# Agent guide for MochiLoad

MochiLoad is a personal, rebranded fork of SideStore (AGPLv3) made for a small group of
non-technical friends. Changes here are not contributions to SideStore. If any change is ever
sent back to SideStore, their rules apply: https://github.com/SideStore/SideStore/blob/develop/AGENTS.md

## Ground rules

- Keep the license and the credits (README and the in-app About/Credits section).
- Users should never see "SideStore" outside the credits. Internal names (the `SideStore`
  scheme, target folders, `SideStore.ipa` from the Makefile, database file names) stay as they
  are, because renaming them touches signing, migrations and build scripts.
- Bundle ID is `com.psxhoz.MochiLoad` (`Build.xcconfig`, `Shared/Extensions/Bundle+AltStore.swift`,
  `AltStore/Info.plist`, both `ReleaseEntitlements.plist` files, `Makefile`). Change them together.
- The default source is `source.json` in this repo (`SideStore/AppConstants.swift`).
- Avoid broad refactors in signing, pairing, networking and Core Data code; those are where
  sideloading breaks. Prefer small, testable UI and text changes.
- Never commit pairing files, certificates, private keys, anisette data, Apple IDs, passwords
  or device UDIDs.

## Layout

- `AltStore/` main app (UIKit + storyboards), `SideStore/` newer SwiftUI views, boot flow, constants
- `AltWidget/` widgets, `SideBackup/` backup helper app, `Shared/` shared extensions
- `Dependencies/` submodules (minimuxer, SideSign); do not edit unless updating dependencies

## Building

Needs macOS + Xcode. `make build fakesign ipa` gives `SideStore.ipa`.
CI: `.github/workflows/build.yml` builds on every push to `main` and publishes
`MochiLoad.ipa` to the `latest-build` release.

## Pulling SideStore fixes

This repo was imported from SideStore commit `4f3d18d` (no shared git history). To bring in
upstream fixes, diff `upstream/develop` against that commit and apply the patch, then re-run the
rebrand checks above.
