import AppKit

/// Owns the menu-bar item and builds the two menus: the menu-bar menu (history
/// plus app commands) and the hotkey pop-up at the cursor (history only).
final class StatusItemController: NSObject, NSMenuDelegate {
    var onShowSettings: (() -> Void)?

    private let store: HistoryStore
    private let pasteService: PasteService
    private let statusItem: NSStatusItem
    private let statusMenu = NSMenu()
    private let popUpMenu = NSMenu()

    init(store: HistoryStore, pasteService: PasteService) {
        self.store = store
        self.pasteService = pasteService
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusMenu.delegate = self
        statusMenu.autoenablesItems = false
        popUpMenu.autoenablesItems = false
        statusItem.menu = statusMenu
        statusItem.button?.image = CowIcon.image()
        statusItem.button?.toolTip = "Cowpy"
        applyVisibility()
    }

    /// With the icon hidden Cowpy is hotkey-only; opening the app again from
    /// Finder brings up Settings (see `AppDelegate`).
    func applyVisibility() {
        let isVisible = Defaults.showsStatusItem
        if statusItem.isVisible != isVisible {
            statusItem.isVisible = isVisible
        }
    }

    func popUpAtCursor() {
        // The pop-up is for pasting quickly, so it carries no app commands;
        // Settings and Quit live in the menu-bar menu only.
        populate(popUpMenu, includesAppCommands: false)
        popUpMenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(statusMenu, includesAppCommands: true)
    }

    // MARK: - Building

    private func populate(_ menu: NSMenu, includesAppCommands: Bool) {
        menu.removeAllItems()

        let pinned = store.pinned()
        let recent = store.unpinned(limit: Defaults.maxHistorySize)

        if pinned.isEmpty && recent.isEmpty {
            let empty = NSMenuItem(title: "Nothing copied yet 🐮", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            addClipItems(pinned: pinned, recent: recent, to: menu)
        }
        guard includesAppCommands else { return }

        menu.addItem(.separator())
        if !recent.isEmpty {
            menu.addItem(makeItem("Clear History…", action: #selector(clearHistory)))
        }
        menu.addItem(makeItem("Settings…", action: #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit Cowpy", action: #selector(quit), key: "q"))
    }

    /// Pinned clips come first and are always inline. Of the rest, the first
    /// few go straight into the menu and the remainder are grouped into
    /// numbered submenus ("11 – 20") so long histories stay navigable.
    /// Numbering runs through the whole menu so every clip has one number.
    private func addClipItems(pinned: [Clip], recent: [Clip], to menu: NSMenu) {
        var number = 0

        if !pinned.isEmpty {
            menu.addItem(.sectionHeader(title: "Pinned"))
            for clip in pinned {
                number += 1
                menu.addItem(makeClipItem(clip, number: number))
            }
            if !recent.isEmpty {
                menu.addItem(.sectionHeader(title: "History"))
            }
        }

        let inlineCount = min(Defaults.inlineItemCount, recent.count)
        for clip in recent.prefix(inlineCount) {
            number += 1
            menu.addItem(makeClipItem(clip, number: number))
        }

        let perFolder = Defaults.itemsPerFolder
        var start = inlineCount
        while start < recent.count {
            let end = min(start + perFolder, recent.count)
            let folder = NSMenuItem(title: "\(number + 1) – \(number + end - start)", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            for clip in recent[start..<end] {
                number += 1
                submenu.addItem(makeClipItem(clip, number: number))
            }
            folder.submenu = submenu
            menu.addItem(folder)
            start = end
        }
    }

    private func makeClipItem(_ clip: Clip, number: Int) -> NSMenuItem {
        let title = "\(number). " + Self.truncate(clip.title, to: Defaults.maxTitleLength)
        let item = makeItem(title, action: #selector(chooseClip(_:)))
        item.representedObject = clip

        // Bare digit shortcuts while the menu is open: 1–9, then 0 for the tenth.
        if number <= 10 {
            item.keyEquivalent = String(number % 10)
            item.keyEquivalentModifierMask = []
        }
        if let text = clip.text {
            item.toolTip = String(text.prefix(500))
        }
        item.image = image(for: clip)
        return item
    }

    private func image(for clip: Clip) -> NSImage? {
        switch clip.kind {
        case .image:
            guard Defaults.showsThumbnails, let data = clip.thumbnail, let image = NSImage(data: data) else {
                return nil
            }
            // Thumbnails are stored at 2x; cap the on-screen height to keep rows compact.
            let maxHeight: CGFloat = 36
            let scale = min(1, maxHeight / max(image.size.height, 1), 120 / max(image.size.width, 1))
            image.size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            return image
        case .files:
            guard let path = store.content(of: clip)?.fileURLs.first?.path else { return nil }
            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 16, height: 16)
            return icon
        case .text, .richText, .url:
            guard Defaults.showsColorSwatches, let text = clip.text, let color = ColorParser.parse(text) else {
                return nil
            }
            return ColorSwatch.image(for: color)
        case .pdf:
            return nil
        }
    }

    private func makeItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Actions

    @objc private func chooseClip(_ sender: NSMenuItem) {
        guard let clip = sender.representedObject as? Clip else { return }

        switch ClipAction(modifiers: NSEvent.modifierFlags) {
        case .paste:
            pasteService.paste(clip)
        case .pastePlainText:
            pasteService.paste(clip, plainTextOnly: true)
        case .pasteAndDelete:
            // `paste` has put the content on the pasteboard by the time it
            // returns, so the clip itself is no longer needed.
            pasteService.paste(clip)
            store.delete(clip)
        case .togglePin:
            store.setPinned(!clip.isPinned, for: clip)
        case .delete:
            store.delete(clip)
        }
    }

    @objc private func clearHistory() {
        guard confirmClearingIfNeeded() else { return }
        store.clear()
    }

    private func confirmClearingIfNeeded() -> Bool {
        guard Defaults.confirmsBeforeClearing else { return true }

        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "Pinned clips are kept. This cannot be undone."
        alert.addButton(withTitle: "Clear History").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        alert.showsSuppressionButton = true

        // Agent apps are never frontmost on their own; without this the alert opens behind other windows.
        NSApp.activate(ignoringOtherApps: true)
        let confirmed = alert.runModal() == .alertFirstButtonReturn
        if confirmed, alert.suppressionButton?.state == .on {
            Defaults.confirmsBeforeClearing = false
        }
        return confirmed
    }

    @objc private func showSettings() {
        onShowSettings?()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    static func truncate(_ text: String, to length: Int) -> String {
        guard text.count > length else { return text }
        return text.prefix(length).trimmingCharacters(in: .whitespaces) + "…"
    }
}
