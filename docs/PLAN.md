# Cowpy — plan

Cowpy is a from-scratch macOS clipboard manager in the spirit of
[Clipy](https://github.com/Clipy/Clipy): a menu-bar history you can pop up at
the cursor with a hotkey, plus reusable snippets. No Clipy code is reused.

## Principles

- **Native and small.** AppKit for the menu bar and menus, SwiftUI for windows.
  Zero third-party dependencies so far (Clipy currently resolves ~40 packages,
  including Firebase and Realm).
- **Private.** No analytics, no network access. History stays in
  `~/Library/Application Support/Cowpy/`. Content flagged as concealed by
  password managers is skipped by default.
- **Boring concurrency.** Everything runs on the main actor
  (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, Swift 6 mode). Pure value types
  are marked `nonisolated`. Move work off the main actor only when profiling
  says so (large image thumbnails are the likely first case).

## Targets

| | |
|---|---|
| Minimum macOS | 14.0 (SwiftData, `SMAppService`, Observation) |
| Toolchain | Xcode 27 / Swift 6 language mode |
| Bundle ID | `com.alamin.Cowpy` |
| Distribution | Direct download (Developer ID + notarisation). Not sandboxed for now. |

## Architecture

```
main.swift ─ AppDelegate ─┬─ ClipboardMonitor ──(ClipContent)──▶ HistoryStore (SwiftData)
                          ├─ StatusItemController ── NSMenu ──▶ PasteService ──▶ NSPasteboard + ⌘V
                          ├─ HotKeyCenter (Carbon) ──▶ StatusItemController.popUpAtCursor()
                          └─ SettingsWindowController ── SettingsView (SwiftUI, @AppStorage)
```

| Piece | File | Notes |
|---|---|---|
| Pasteboard snapshot | `Clipboard/ClipContent.swift` | Value type: reads/writes `NSPasteboard`, derives kind, title, hash, thumbnail. Encoded as a binary plist into `Clip.payload`. |
| Change detection | `Clipboard/ClipboardMonitor.swift` | Polls `changeCount` every 0.5 s (macOS has no change notification). Honours excluded apps. |
| Pasting | `Clipboard/PasteService.swift` | Writes the clip back, tells the monitor to ignore that write, synthesises ⌘V via `CGEvent` (needs Accessibility). |
| Model | `Storage/Clip.swift` | Menu-facing fields inline; payload and thumbnail in external storage. |
| Persistence | `Storage/HistoryStore.swift` | De-duplicates by content hash, trims to the configured size, keeps pinned clips. |
| Menu | `Menu/StatusItemController.swift` | Two menus: menu-bar (clips + app commands) and hotkey pop-up (clips only). Pinned section, inline items + numbered submenus, digit key equivalents, thumbnails, file icons, colour swatches. |
| Clip actions | `Menu/ClipAction.swift` | Maps held modifiers to an action. Exact-match only, and ⌘/⇧ never remove anything, because the ⇧⌘V hotkey often leaves those keys down. |
| Colours | `Menu/ColorSwatch.swift` | `ColorParser` (requires `#` so one-time codes are not mistaken for colours) and the swatch image. |
| Icon | `Menu/CowIcon.swift` | Template glyph drawn in code. |
| Search | `Search/` | `SearchPanelController` (non-activating `NSPanel`, AppKit key monitor mapped through `SearchKey`), `SearchModel` (`@Observable` query/results/selection), `SearchFilter` (pure matching), `SearchView` (SwiftUI). |
| Snippets | `Snippets/` | `SnippetStore` (separate SwiftData container), `SnippetArchive` (Clipy-compatible XML), `SnippetsEditorView` (SwiftUI, `@Query` + `@Bindable` straight onto the models). |
| Hotkeys | `HotKeys/` | `HotKeyCenter` wraps `RegisterEventHotKey` (no permission required). `HotKeyManager` owns the user's choices, persistence and conflicts, and talks to the centre through `HotKeyRegistering` so tests use a fake. `KeyboardLayout` translates key codes for the current layout. |
| Preferences | `App/Defaults.swift`, `Settings/` | One set of keys shared by services (`Defaults`) and views (`@AppStorage`). |

## Roadmap

### M1 — History (done)
- [x] Capture text, rich text, HTML, URLs, images, PDFs, files
- [x] Persist, de-duplicate, trim
- [x] Menu-bar menu and ⇧⌘V pop-up at the cursor
- [x] Paste on select, ⌥ for plain text
- [x] Settings window, launch at login
- [x] Skip concealed/transient pasteboard content
- [x] Menu, hotkey and auto-paste verified on a real desktop session
- [x] Hotkey pop-up shows clips only; Settings and Quit live in the menu-bar menu
- [x] Layout-aware key code for "v" (done in M4)

### M2 — Menu polish (built, needs a hands-on check)
- [x] Colour swatch for `#rgb[a]`, `#rrggbb[aa]`, `rgb()` / `rgba()` strings
- [x] Modifier actions when choosing a clip: ⌥ plain text, ⇧ pin/unpin, ⌃ remove, ⌃⌥ paste then remove
- [x] Pinned section at the top of the menu; pinned clips survive trim, expiry and Clear History
- [x] Confirmation before Clear History (with "don't ask again"), clear on quit, age-based expiry
- [x] Per-type capture toggles (text, formatting, images, PDFs, files)
- [x] Option to hide the menu-bar icon; reopening the app shows Settings
- [x] Tabbed settings window (General / Menu / History / Capture)
- [ ] **Manually verify** the modifier actions, pinned section and Clear History alert
- [ ] Make the modifier mapping configurable (fixed for now)

### M3 — Snippets (built, needs a hands-on check)
- [x] `SnippetFolder` / `Snippet` models, ordered, enable/disable — in their own `Snippets.store`, so clearing or migrating history can never touch them
- [x] Snippets section (one submenu per folder) in the menu-bar menu and the ⇧⌘V pop-up
- [x] Snippets-only pop-up on ⇧⌘B
- [x] Editor window: split view, add/delete, drag to reorder snippets, Move Up/Down for folders, confirmation before deleting a non-empty folder
- [x] Import / export in Clipy's XML format (import appends, never replaces)
- [x] Pasting a snippet does not add it to the history
- [ ] **Manually verify** the editor, both pop-ups and an import from Clipy
- [ ] Placeholders in snippets (date, clipboard contents, cursor position)

### M4 — Shortcuts & exclusions (built, needs a hands-on check)
- [x] Shortcut recorder in Settings → Shortcuts; shortcuts pause while recording so the old one cannot fire
- [x] Separate shortcuts for clips + snippets (⇧⌘V), clips only (none by default) and snippets only (⇧⌘B)
- [x] Conflict handling: a combo used by another Cowpy action is refused, one the system refuses keeps the old shortcut, a cleared shortcut stays cleared across launches
- [x] Modifiers still held from the shortcut are ignored when a clip is chosen, so a custom shortcut such as ⌃⌥C cannot trigger "paste then remove"
- [x] Layout-aware key names and ⌘V synthesis (Dvorak, AZERTY, "Dvorak – QWERTY ⌘")
- [x] Ignored-apps editor in Settings → Capture (running apps, or choose from Applications)
- [ ] **Manually verify** recording a shortcut, the leftover-modifier behaviour and an ignored app
- [ ] Per-snippet-folder shortcuts

### M5 — Search (built, needs a hands-on check)
- [x] Floating search panel on ⌃⌘V (customisable) and from "Search…" in the menu-bar menu; non-activating, so the app you were in stays frontmost and receives the paste
- [x] Filters clips (pinned first) and enabled snippets as you type; every term must match, ignoring case, accents and width
- [x] Keyboard: ↑↓/Page keys move, ↩ pastes, ⌘1–9 quick-paste, ⎋ clears the query then closes; the same modifier actions as the menu (⌥ plain, ⇧ pin, ⌃ remove, ⌃⌥ paste then remove)
- [x] Closes when it loses focus; input-method composition keeps its Return and arrow keys
- [ ] **Manually verify** focus on open, typing, pasting into the previous app, and click-outside to dismiss
- [ ] Move to SQLite FTS if histories grow past a few thousand clips (in-memory filtering is instant at the current 1,000-clip cap)
- [ ] Preview pane for the selected clip (full text, full-size image)

### M6 — Ship
- [ ] App icon (full-colour cow)
- [ ] Developer ID signing, notarisation, DMG
- [ ] Sparkle 2 for updates (first third-party dependency)
- [ ] Decide licence; localisation via String Catalogs
- [ ] Optional: import history from Clipy

## Open decisions

1. **Sandbox / Mac App Store.** Synthesising ⌘V and the Accessibility prompt are
   the friction points. Staying unsandboxed keeps M1–M5 simple; revisit at M6.
2. **SwiftData vs GRDB.** SwiftData keeps dependencies at zero and is plenty for
   a few thousand rows; search filters in memory. If the history cap is ever
   raised enough to need FTS5, move `HistoryStore` to GRDB — it is the only
   type that touches SwiftData besides the `Clip` model.
3. **Name.** "Cowpy" was clear in a web search on 2026-09-19; App Store name
   reservation, trademark and domain have not been checked.

## Development notes

- The project uses Xcode's folder-synchronised groups: add a file under
  `Cowpy/` or `CowpyTests/` and it is part of the target, no project edits.
- `scripts/install.sh` builds Release, installs to `/Applications` and
  relaunches. macOS ties the Accessibility grant to the code signature, so an
  ad-hoc signed build loses it on **every reinstall** (System Settings still
  shows the toggle on, but it belongs to the old build; `tccutil reset
  Accessibility com.alamin.Cowpy` clears the stale entry). The script signs
  with an "Apple Development" certificate when the keychain has one — a free
  Apple ID in Xcode is enough — which keeps the grant. The team ID is passed on
  the command line, so it never lands in the repository.
- Cowpy asks for the Accessibility permission at most once per launch.
- There is no UI test target. To eyeball the settings panes, run the opt-in
  snapshot tests, which write PNGs to a directory of your choice:
  `TEST_RUNNER_COWPY_SNAPSHOT_DIR=/some/dir xcodebuild … test -only-testing:CowpyTests/SnapshotTests`
- Settings changes never delete history immediately: a smaller size applies at
  the next copy and a shorter retention at the next 5-minute tick.
- Tests are hosted in the app; `AppDelegate` detects XCTest and skips start-up
  so tests never watch the real clipboard. Pasteboard tests use uniquely named
  private pasteboards, stores are in-memory.
