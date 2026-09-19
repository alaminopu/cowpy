import AppKit
import Carbon.HIToolbox

/// Puts a history entry back on the pasteboard and, if allowed, pastes it into
/// the frontmost app by synthesising ⌘V.
final class PasteService {
    private let store: HistoryStore
    private let monitor: ClipboardMonitor
    private let pasteboard: NSPasteboard

    init(store: HistoryStore, monitor: ClipboardMonitor, pasteboard: NSPasteboard = .general) {
        self.store = store
        self.monitor = monitor
        self.pasteboard = pasteboard
    }

    func paste(_ clip: Clip, plainTextOnly: Bool = false) {
        guard let content = store.content(of: clip) else { return }

        content.write(to: pasteboard, plainTextOnly: plainTextOnly)
        // We already know this clip; bump it instead of re-recording it.
        monitor.ignoreCurrentChange()
        store.touch(clip)

        guard Defaults.pastesAutomatically else { return }
        guard AccessibilityPermission.isTrusted(prompt: true) else { return }

        // Let the menu finish closing so the keystroke lands in the target app.
        DispatchQueue.main.async {
            Self.postCommandV()
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        // Ignore the physical keyboard for a moment so held modifiers
        // (e.g. ⌥ for plain-text paste) do not leak into the synthetic ⌘V.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        // TODO: resolve the key code for "v" from the current keyboard layout (Dvorak etc.).
        let keyCode = CGKeyCode(kVK_ANSI_V)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}

enum AccessibilityPermission {
    /// Posting key events to other apps requires the Accessibility permission.
    static func isTrusted(prompt: Bool) -> Bool {
        // String literal instead of `kAXTrustedCheckOptionPrompt`: the imported
        // global is a mutable var, which Swift 6 rejects as not concurrency-safe.
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
