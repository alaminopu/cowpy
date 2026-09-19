import AppKit

/// Cowpy has no Dock icon, but it still needs a main menu: without an Edit
/// menu, ⌘C/⌘V/⌘A do not work in the settings window's text fields.
enum MainMenu {
    static func make(target: AnyObject, settingsAction: Selector, aboutAction: Selector) -> NSMenu {
        let mainMenu = NSMenu()
        mainMenu.addItem(submenuItem(appMenu(target: target, settingsAction: settingsAction, aboutAction: aboutAction)))
        mainMenu.addItem(submenuItem(editMenu()))
        mainMenu.addItem(submenuItem(windowMenu()))
        return mainMenu
    }

    private static func appMenu(target: AnyObject, settingsAction: Selector, aboutAction: Selector) -> NSMenu {
        let menu = NSMenu(title: "Cowpy")
        let about = menu.addItem(withTitle: "About Cowpy", action: aboutAction, keyEquivalent: "")
        about.target = target
        menu.addItem(.separator())
        let settings = menu.addItem(withTitle: "Settings…", action: settingsAction, keyEquivalent: ",")
        settings.target = target
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Cowpy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        return menu
    }

    private static func submenuItem(_ submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }
}
