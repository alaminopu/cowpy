import AppKit

// Cowpy is a menu-bar agent (LSUIElement) with no storyboard, so the
// application and its delegate are wired up by hand.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
