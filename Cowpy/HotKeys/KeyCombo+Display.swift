import AppKit
import Carbon.HIToolbox

nonisolated extension KeyCombo {
    init(keyCode: Int, modifiers: NSEvent.ModifierFlags) {
        var carbon = 0
        if modifiers.contains(.command) { carbon |= cmdKey }
        if modifiers.contains(.shift) { carbon |= shiftKey }
        if modifiers.contains(.option) { carbon |= optionKey }
        if modifiers.contains(.control) { carbon |= controlKey }
        self.init(keyCode: UInt32(keyCode), carbonModifiers: UInt32(carbon))
    }

    var modifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if carbonModifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbonModifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbonModifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        return flags
    }

    /// Modifier symbols in the order macOS menus use: ⌃⌥⇧⌘.
    var modifierSymbols: String {
        var symbols = ""
        if modifiers.contains(.control) { symbols += "⌃" }
        if modifiers.contains(.option) { symbols += "⌥" }
        if modifiers.contains(.shift) { symbols += "⇧" }
        if modifiers.contains(.command) { symbols += "⌘" }
        return symbols
    }

    /// A global shortcut needs ⌘, ⌃ or ⌥ (⇧ alone would hijack typing), unless
    /// it is a function key, which is safe on its own.
    var isUsableAsHotKey: Bool {
        !modifiers.isDisjoint(with: [.command, .control, .option]) || Self.functionKeyNames[Int(keyCode)] != nil
    }

    static let functionKeyNames: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    static let specialKeyNames: [Int: String] = [
        kVK_Return: "↩", kVK_ANSI_KeypadEnter: "⌅", kVK_Tab: "⇥", kVK_Space: "Space",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    ]
}

extension KeyCombo {
    /// E.g. "⇧⌘V". Letters follow the current keyboard layout.
    var displayString: String {
        modifierSymbols + keyName
    }

    private var keyName: String {
        if let name = Self.specialKeyNames[Int(keyCode)] ?? Self.functionKeyNames[Int(keyCode)] {
            return name
        }
        if let character = KeyboardLayout.character(for: keyCode), !character.trimmingCharacters(in: .whitespaces).isEmpty {
            return character.uppercased()
        }
        return "Key \(keyCode)"
    }
}

/// What a key press means while a shortcut is being recorded.
nonisolated enum RecorderInput: Equatable {
    case cancel
    case clear
    case combo(KeyCombo)
    /// Not enough modifiers to be a global shortcut; keep listening.
    case rejected

    init(keyCode: Int, modifiers: NSEvent.ModifierFlags) {
        let relevant = modifiers.intersection([.command, .shift, .option, .control])
        if relevant.isEmpty, keyCode == kVK_Escape {
            self = .cancel
        } else if relevant.isEmpty, keyCode == kVK_Delete || keyCode == kVK_ForwardDelete {
            self = .clear
        } else {
            let combo = KeyCombo(keyCode: keyCode, modifiers: relevant)
            self = combo.isUsableAsHotKey ? .combo(combo) : .rejected
        }
    }
}
