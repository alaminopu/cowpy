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
    /// The history opens with ⇧⌘V, so those keys are often still down when a
    /// clip is chosen. ⌘ is therefore never a trigger, nothing that removes a
    /// clip involves ⇧, and a leftover ⇧⌘ pastes normally.
    init(modifiers: NSEvent.ModifierFlags) {
        switch modifiers.intersection([.command, .shift, .option, .control]) {
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
