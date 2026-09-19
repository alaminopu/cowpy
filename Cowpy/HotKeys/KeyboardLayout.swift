import Carbon.HIToolbox
import Foundation

/// Translates between hardware key codes and the characters they produce in
/// the user's current keyboard layout (QWERTY, Dvorak, AZERTY, …).
///
/// Text Input Source calls must happen on the main thread, so this stays on the main actor.
enum KeyboardLayout {
    /// The character a key produces, or `nil` for keys that produce none.
    static func character(for keyCode: UInt32, carbonModifiers: UInt32 = 0) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data

        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                (carbonModifiers >> 8) & 0xFF,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length)
    }

    /// The key that produces `character` while `carbonModifiers` are held.
    ///
    /// Looking it up with ⌘ held matters for layouts such as "Dvorak – QWERTY ⌘",
    /// where shortcuts live on different keys than the letters themselves.
    static func keyCode(for character: String, carbonModifiers: UInt32 = 0) -> UInt32? {
        (0..<128).first { keyCode in
            self.character(for: keyCode, carbonModifiers: carbonModifiers)?.lowercased() == character.lowercased()
        }
    }
}
