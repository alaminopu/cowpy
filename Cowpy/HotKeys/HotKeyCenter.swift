import AppKit
import Carbon.HIToolbox

/// A key plus Carbon modifier flags (`cmdKey`, `shiftKey`, `optionKey`, `controlKey`).
nonisolated struct KeyCombo: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    /// ⇧⌘V, the same default Clipy uses for its main menu.
    static let defaultMainMenu = KeyCombo(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(cmdKey | shiftKey))

    /// ⇧⌘B, Clipy's default for the snippets menu.
    static let defaultSnippetsMenu = KeyCombo(keyCode: UInt32(kVK_ANSI_B), carbonModifiers: UInt32(cmdKey | shiftKey))
}

/// System-wide hotkeys via Carbon's `RegisterEventHotKey`, which is still the
/// only API for this that needs no Accessibility permission.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private static let signature: OSType = 0x434F_5750 // 'COWP'

    private var handlers: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private init() {}

    /// Returns a token for `unregister`, or `nil` if the combo is already taken system-wide.
    @discardableResult
    func register(_ combo: KeyCombo, handler: @escaping () -> Void) -> UInt32? {
        installEventHandlerIfNeeded()

        let id = nextID
        nextID += 1

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return nil }

        hotKeyRefs[id] = ref
        handlers[id] = handler
        return id
    }

    func unregister(_ token: UInt32) {
        if let ref = hotKeyRefs.removeValue(forKey: token) {
            UnregisterEventHotKey(ref)
        }
        handlers[token] = nil
    }

    fileprivate func handleHotKey(id: UInt32) {
        handlers[id]?()
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), hotKeyEventCallback, 1, &spec, nil, &eventHandler)
    }
}

/// C callback for Carbon. Hotkey events are delivered on the main thread.
private nonisolated func hotKeyEventCallback(
    _: EventHandlerCallRef?,
    event: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    let id = hotKeyID.id
    MainActor.assumeIsolated {
        HotKeyCenter.shared.handleHotKey(id: id)
    }
    return noErr
}
