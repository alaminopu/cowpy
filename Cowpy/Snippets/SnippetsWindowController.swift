import AppKit
import SwiftUI

final class SnippetsWindowController: NSWindowController, NSWindowDelegate {
    private let store: SnippetStore

    init(store: SnippetStore) {
        self.store = store
        let rootView = SnippetsEditorView(store: store).modelContainer(store.container)
        let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
        window.title = "Snippets"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 760, height: 480))
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SnippetsWindow")
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        guard let window else { return }
        if !window.isVisible, !window.setFrameUsingName("SnippetsWindow") {
            window.center()
        }
        // Agent apps are never frontmost on their own.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Edits are bound straight to the models; make sure they reach disk.
        store.save()
    }
}
