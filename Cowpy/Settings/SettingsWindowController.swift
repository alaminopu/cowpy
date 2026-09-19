import AppKit
import SwiftUI

/// Hosts the SwiftUI settings in a plain window. SwiftUI's `Settings` scene
/// cannot be opened from AppKit code in an agent app, so Cowpy owns the window.
final class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        window.title = "Cowpy Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show() {
        guard let window else { return }
        if !window.isVisible {
            window.center()
        }
        // Agent apps are never frontmost on their own.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
