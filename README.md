<div align="center">
  <img src="docs/logo.png" width="128" alt="BlockBook logo">
  <h1>🔒 BlockBook</h1>
  <p>Manual-launch screen locker for macOS</p>
  <p>
    <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2013%2B-blue?style=flat-square&logo=apple">
    <img alt="Swift" src="https://img.shields.io/badge/swift-6.0-orange?style=flat-square&logo=swift">
    <img alt="License" src="https://img.shields.io/badge/license-MIT-green?style=flat-square">
    <img alt="Release" src="https://img.shields.io/github/v/release/efekurucay/blockbook?style=flat-square&color=purple">
    <img alt="Repo Size" src="https://img.shields.io/github/repo-size/efekurucay/blockbook?style=flat-square">
  </p>
</div>

<!-- Add a screenshot here: docs/screenshot.png -->

## Overview

BlockBook is a manual-launch screen locker for macOS built with Swift 6 and AppKit. When you open it, the current screen contents remain visible while keyboard and mouse input are blocked across all connected displays. The lock can show a centered image overlay, unlock with a password through `⌘E`, and swap the lock image at runtime with `⌘R`.

## Features

- Instant lock: screen contents stay visible, input blocked immediately
- Floating image card displayed on first input attempt or after a short delay
- Password-protected unlock via `⌘E`
- Replace lock image at any time with `⌘R`
- Multi-display support: covers all connected screens
- No login item or background process — launches only when you open it
- Ad-hoc signed by default, compatible with real Apple Developer identity

## Installation

#### Download (recommended)

1. Go to [Releases](../../releases/latest)
2. Download `BlockBook-x.x.x.dmg`
3. Open the DMG and drag BlockBook to Applications
4. Launch BlockBook
5. When prompted, grant Accessibility access in:
   `System Settings → Privacy & Security → Accessibility`

#### Build from Source

Requirements:

- macOS 13.0+
- Xcode 15+ / Swift 6 toolchain
- `create-dmg` (for DMG packaging): `brew install create-dmg`

```bash
git clone https://github.com/efekurucay/blockbook.git
cd blockbook
./scripts/build_app.sh
./scripts/package_dmg.sh
```

## Usage

Launch BlockBook to activate the lock immediately. While the lock is active, the screen stays visible but input is blocked until the correct password is entered.

| Shortcut | Action |
|----------|--------|
| Launch app | Activates lock immediately |
| `⌘E` | Opens password prompt |
| `⌘R` | Replace lock image |
| Correct password | Unlocks and quits the app |

## Configuration

Edit `Sources/BlockBook/LockConfiguration.swift` to change the lock defaults:

```swift
static let `default` = LockConfiguration(
    unlockPassword: "1234",              // change this
    unlockShortcut: .commandE,
    changeImageShortcut: .commandR,
    previewRevealDelay: 1.5,             // seconds before image appears
    unlockTitle: "Kilidi Ac",
    unlockMessage: "Devam etmek icin parolayi girin.",
    invalidPasswordMessage: "Parola yanlis. Tekrar deneyin.",
    imagePickerTitle: "Gorsel Sec",
    imagePickerMessage: "Kilitte gosterilecek gorseli secin veya degistirin."
)
```

## Permissions

BlockBook relies on a macOS Accessibility grant because it uses a session-level `CGEventTap` to intercept and block keyboard and mouse events system-wide. Without that permission, the app exits immediately instead of entering a partially locked state.

## Releasing

```bash
./scripts/create_release.sh v1.0.0
```

## Limitations

- Some protected macOS system shortcuts may bypass the lock depending on OS policy
- Requires Accessibility permission; app terminates immediately if not granted

## License

MIT License — Copyright (c) 2026 Yahya Efe Kuruçay
