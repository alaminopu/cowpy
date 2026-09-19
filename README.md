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

## Build

Requires Xcode 27+ and macOS 14+.

```sh
xcodebuild -project Cowpy.xcodeproj -scheme Cowpy -derivedDataPath build build
open build/Build/Products/Debug/Cowpy.app

xcodebuild -project Cowpy.xcodeproj -scheme Cowpy -derivedDataPath build test
```

To install into `/Applications` and relaunch: `scripts/install.sh`.

Or open `Cowpy.xcodeproj` and run. Cowpy has no Dock icon — look for the cow in
the menu bar.

Auto-paste needs the Accessibility permission (System Settings → Privacy &
Security → Accessibility). An ad-hoc signed build loses that grant on every
reinstall. Add your Apple ID in Xcode (a free one works) and create an Apple
Development certificate; `scripts/install.sh` then signs with it and the grant
sticks.
