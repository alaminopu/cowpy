import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A panel that can take keyboard input without activating Cowpy, so the app
/// the user was working in stays frontmost and receives the paste.
private final class SearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Shows the search panel and turns key presses in it into actions.
///
/// Navigation keys are handled here with an AppKit event monitor rather than
/// in SwiftUI, because the focused text field would otherwise consume them.
final class SearchPanelController: NSObject, NSWindowDelegate {
    /// Time for the target app's window to become key again after the panel closes.
    private static let pasteDelay: TimeInterval = 0.06

    private let model: SearchModel
    private let store: HistoryStore
    private let pasteService: PasteService
    private let panel: SearchPanel

    private var eventMonitor: Any?
    /// Modifiers of the opening shortcut that have not been released yet; see `ClipAction`.
    private var leftoverModifiers: NSEvent.ModifierFlags = []

    init(model: SearchModel, store: HistoryStore, pasteService: PasteService) {
        self.model = model
        self.store = store
        self.pasteService = pasteService

        panel = SearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        super.init()

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        // Cowpy is never the active app, so a panel that hides on deactivate would never show.
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: SearchView(model: model) { [weak self] result in
            self?.choose(result, modifiers: NSEvent.modifierFlags)
        })
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(openedWith combo: KeyCombo? = nil) {
        isVisible ? close() : show(openedWith: combo)
    }

    func show(openedWith combo: KeyCombo? = nil) {
        model.beginSession()
        leftoverModifiers = (combo?.modifiers ?? []).intersection(NSEvent.modifierFlags)
        position()
        panel.orderFrontRegardless()
        panel.makeKey()
        startMonitoringKeys()
    }

    func close() {
        stopMonitoringKeys()
        guard panel.isVisible else { return }
        panel.orderOut(nil)
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // Clicking anywhere else dismisses the panel, like Spotlight.
        close()
    }

    // MARK: - Layout

    /// Centred horizontally on the screen under the mouse, a little above the middle.
    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + (visible.height - size.height) * 0.62
        ))
    }

    // MARK: - Keys

    private func startMonitoringKeys() {
        stopMonitoringKeys()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event)
        }
    }

    private func stopMonitoringKeys() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
    }

    /// Returns `nil` when the event was consumed.
    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.type == .flagsChanged {
            leftoverModifiers.formIntersection(event.modifierFlags)
            return event
        }
        // While an input method is composing (e.g. Japanese, accents), Return
        // and the arrows belong to it.
        if let editor = panel.firstResponder as? NSTextView, editor.hasMarkedText() {
            return event
        }

        switch SearchKey(keyCode: Int(event.keyCode), characters: event.charactersIgnoringModifiers, modifiers: event.modifierFlags) {
        case .move(let offset):
            model.moveSelection(by: offset)
        case .choose:
            if let selection = model.selection {
                choose(selection, modifiers: event.modifierFlags)
            }
        case .quickPick(let index):
            guard model.results.indices.contains(index) else { return nil }
            choose(model.results[index], modifiers: [])
        case .escape:
            if model.query.isEmpty {
                close()
            } else {
                model.query = ""
            }
        case .text:
            return event
        }
        return nil
    }

    // MARK: - Actions

    private func choose(_ result: SearchResult, modifiers: NSEvent.ModifierFlags) {
        switch result {
        case .snippet(let snippet):
            close()
            pasteService.paste(text: snippet.content, delay: Self.pasteDelay)

        case .clip(let clip):
            switch ClipAction(modifiers: modifiers, ignoring: leftoverModifiers) {
            case .paste:
                close()
                pasteService.paste(clip, delay: Self.pasteDelay)
            case .pastePlainText:
                close()
                pasteService.paste(clip, plainTextOnly: true, delay: Self.pasteDelay)
            case .pasteAndDelete:
                close()
                pasteService.paste(clip, delay: Self.pasteDelay)
                store.delete(clip)
            case .togglePin:
                store.setPinned(!clip.isPinned, for: clip)
                model.reload()
            case .delete:
                store.delete(clip)
                model.reload()
            }
        }
    }
}

/// What a key press in the search panel means.
nonisolated enum SearchKey: Equatable {
    case move(Int)
    case choose
    /// ⌘1–⌘9: paste that row straight away. Zero-based.
    case quickPick(Int)
    case escape
    /// Anything else goes to the text field.
    case text

    init(keyCode: Int, characters: String?, modifiers: NSEvent.ModifierFlags) {
        let relevant = modifiers.intersection([.command, .shift, .option, .control])
        switch keyCode {
        case kVK_UpArrow: self = .move(-1)
        case kVK_DownArrow: self = .move(1)
        case kVK_PageUp: self = .move(-8)
        case kVK_PageDown: self = .move(8)
        case kVK_Return, kVK_ANSI_KeypadEnter: self = .choose
        case kVK_Escape: self = .escape
        default:
            if relevant == [.command], let digit = characters.flatMap(Int.init), (1...9).contains(digit) {
                self = .quickPick(digit - 1)
            } else {
                self = .text
            }
        }
    }
}
