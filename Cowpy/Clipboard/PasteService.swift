import AppKit
import Carbon.HIToolbox

/// Puts a history entry back on the pasteboard and, if allowed, pastes it into
/// the frontmost app by synthesising ⌘V.
final class PasteService {
    private let store: HistoryStore
    private let monitor: ClipboardMonitor
    private let pasteboard: NSPasteboard
    /// The system Accessibility prompt is shown at most once per launch. If the
    /// grant is missing or stale, asking again on every paste only gets in the
    /// way; the clip is on the pasteboard either way and Settings shows a warning.
    private var hasPromptedForAccessibility = false

    init(store: HistoryStore, monitor: ClipboardMonitor, pasteboard: NSPasteboard = .general) {
        self.store = store
        self.monitor = monitor
        self.pasteboard = pasteboard
    }

    /// - Parameter delay: extra time before ⌘V is sent. Menus need none; a
    ///   panel that has just closed needs a moment for the target app's window
    ///   to become key again.
    func paste(_ clip: Clip, plainTextOnly: Bool = false, delay: TimeInterval = 0) {
        guard let content = store.content(of: clip) else { return }

        content.write(to: pasteboard, plainTextOnly: plainTextOnly)
        // We already know this clip; bump it instead of re-recording it.
        monitor.ignoreCurrentChange()
        store.touch(clip)
        pasteIntoFrontmostApp(after: delay)
    }

    /// Pastes a snippet. Snippets are not recorded in the history.
    func paste(text: String, delay: TimeInterval = 0) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        monitor.ignoreCurrentChange()
        pasteIntoFrontmostApp(after: delay)
    }

    private func pasteIntoFrontmostApp(after delay: TimeInterval) {
        guard Defaults.pastesAutomatically else { return }

        let shouldPrompt = !hasPromptedForAccessibility
        hasPromptedForAccessibility = true
        guard AccessibilityPermission.isTrusted(prompt: shouldPrompt) else { return }

        // Even with no delay, wait a run-loop turn so the menu finishes
        // closing and the keystroke lands in the target app.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
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

        // "V" is not on the same key in every layout (Dvorak, AZERTY, …).
        let keyCode = CGKeyCode(KeyboardLayout.keyCode(for: "v", carbonModifiers: UInt32(cmdKey)) ?? UInt32(kVK_ANSI_V))
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
