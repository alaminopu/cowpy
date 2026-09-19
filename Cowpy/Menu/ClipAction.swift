import AppKit

/// What choosing a clip does, decided by the modifier keys held at that moment.
nonisolated enum ClipAction: Equatable, Sendable, CaseIterable {
    case paste
    case pastePlainText
    case togglePin
    case delete
    case pasteAndDelete

    /// Modifiers must match exactly; any other combination is a normal paste.
    ///
    /// The pop-up opens with a shortcut (⇧⌘V by default), and those keys are
    /// often still down when a clip is chosen. Two safeguards keep that from
    /// triggering anything: `leftover` names the shortcut's modifiers that have
    /// been held continuously since the menu opened, which are ignored; and
    /// with the default shortcut ⌘ is never a trigger and nothing that removes
    /// a clip involves ⇧.
    init(modifiers: NSEvent.ModifierFlags, ignoring leftover: NSEvent.ModifierFlags = []) {
        switch modifiers.subtracting(leftover).intersection([.command, .shift, .option, .control]) {
        case [.option]: self = .pastePlainText
        case [.shift]: self = .togglePin
        case [.control]: self = .delete
        case [.control, .option]: self = .pasteAndDelete
        default: self = .paste
        }
    }

    /// The modifiers that trigger this action, for the cheat sheet in Settings.
    var modifierSymbols: String? {
        switch self {
        case .paste: nil
        case .pastePlainText: "⌥"
        case .togglePin: "⇧"
        case .delete: "⌃"
        case .pasteAndDelete: "⌃⌥"
        }
    }

    var summary: String {
        switch self {
        case .paste: "Paste"
        case .pastePlainText: "Paste as plain text"
        case .togglePin: "Pin or unpin"
        case .delete: "Remove from history"
        case .pasteAndDelete: "Paste, then remove from history"
        }
    }
}
