# Cowpy 🐮

A small, native clipboard manager for macOS. Everything you copy lands in a
menu-bar history; press **⇧⌘V** anywhere to pop it up at the cursor and paste.

Inspired by [Clipy](https://github.com/Clipy/Clipy), written from scratch in
Swift with no third-party dependencies, no analytics and no network access.

## Features

- History of text, rich text, links, images, PDFs and files
- ⇧⌘V opens the history at the cursor; press `1`–`9`/`0` to pick. Shortcuts are customisable
- ⌃⌘V opens a search panel: type to filter clips and snippets, ↩ to paste, ⌘1–9 to quick-paste
- Pastes straight into the active app
- Hold a key while choosing a clip: ⌥ plain text · ⇧ pin/unpin · ⌃ remove · ⌃⌥ paste then remove
- Pinned clips stay at the top and are never trimmed or cleared
- Snippets: folders of text you paste often, in the menu and on ⇧⌘B, with an
  editor and Clipy-compatible import/export
- Image thumbnails, file icons, colour swatches, numbered submenus for long histories
- Skips passwords and other concealed content; choose which kinds of data are recorded and which apps to ignore
- History size limit, optional expiry, clear on quit
- Launch at login; optionally hide the menu-bar icon and use the hotkey only

See [docs/PLAN.md](docs/PLAN.md) for the architecture and roadmap (snippets,
custom shortcuts, excluded apps, search).

If you hide the menu-bar icon, open Cowpy again from Applications or Spotlight
to get back to Settings.

## Install

With [Homebrew](https://brew.sh):

```sh
brew tap alaminopu/cowpy https://github.com/alaminopu/cowpy
brew install --cask cowpy
```

Then open Cowpy from Applications or Spotlight and look for the cow in the
menu bar. Or download the disk image from
[Releases](https://github.com/alaminopu/cowpy/releases) and drag Cowpy to
Applications.

Cowpy is free and open source, and is **not notarised** by Apple (that needs a
paid developer account). What that means in practice:

- Homebrew installs it ready to run. If you use the disk image instead, the
  first launch needs right-click → **Open**, or System Settings → Privacy &
  Security → **Open Anyway**.
- To paste for you, Cowpy needs the Accessibility permission (System Settings →
  Privacy & Security → Accessibility). macOS ties that permission to the exact
  build of an un-notarised app, so after every update remove Cowpy from that
  list and add it again. If pasting stops after an update, this is why.

To update: `brew upgrade --cask cowpy`. To remove everything including your
history and snippets: `brew uninstall --zap --cask cowpy`.

## Build

Requires Xcode 27+ and macOS 14+.

```sh
xcodebuild -project Cowpy.xcodeproj -scheme Cowpy -derivedDataPath build build
open build/Build/Products/Debug/Cowpy.app

xcodebuild -project Cowpy.xcodeproj -scheme Cowpy -derivedDataPath build test
```

To install into `/Applications` and relaunch: `scripts/install.sh`.
To build a disk image: `scripts/make-dmg.sh` (output in `dist/`). To publish a
version — disk image, GitHub release and Homebrew cask — bump
`MARKETING_VERSION` and run `scripts/release.sh`.

Or open `Cowpy.xcodeproj` and run. Cowpy has no Dock icon — look for the cow in
the menu bar.

Auto-paste needs the Accessibility permission (System Settings → Privacy &
Security → Accessibility). An ad-hoc signed build loses that grant on every
reinstall. Add your Apple ID in Xcode (a free one works) and create an Apple
Development certificate; `scripts/install.sh` then signs with it and the grant
sticks.

## Licence

[MIT](LICENSE). Inspired by [Clipy](https://github.com/Clipy/Clipy); no Clipy code is used.
