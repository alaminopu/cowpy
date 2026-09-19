import AppKit
import Carbon.HIToolbox
import Testing
@testable import Cowpy

private final class FakeRegistrar: HotKeyRegistering {
    var refused: Set<KeyCombo> = []
    private(set) var registered: [UInt32: KeyCombo] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextToken: UInt32 = 1

    func register(_ combo: KeyCombo, handler: @escaping () -> Void) -> UInt32? {
        guard !refused.contains(combo), !registered.values.contains(combo) else { return nil }
        let token = nextToken
        nextToken += 1
        registered[token] = combo
        handlers[token] = handler
        return token
    }

    func unregister(_ token: UInt32) {
        registered[token] = nil
        handlers[token] = nil
    }

    func press(_ combo: KeyCombo) {
        for (token, registeredCombo) in registered where registeredCombo == combo {
            handlers[token]?()
        }
    }
}

struct HotKeyManagerTests {
    private let shiftCommandV = KeyCombo(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(cmdKey | shiftKey))
    private let shiftCommandB = KeyCombo(keyCode: UInt32(kVK_ANSI_B), carbonModifiers: UInt32(cmdKey | shiftKey))
    private let controlCommandV = KeyCombo(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(cmdKey | controlKey))
    private let controlOptionC = KeyCombo(keyCode: UInt32(kVK_ANSI_C), carbonModifiers: UInt32(controlKey | optionKey))

    private func makeDefaults() -> UserDefaults {
        let name = "com.alamin.CowpyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func startsWithClipyDefaults() {
        let registrar = FakeRegistrar()
        let manager = HotKeyManager(registrar: registrar, defaults: makeDefaults())
        manager.start()

        #expect(manager.combos == [.main: shiftCommandV, .snippets: shiftCommandB, .search: controlCommandV])
        #expect(Set(registrar.registered.values) == [shiftCommandV, shiftCommandB, controlCommandV])
        #expect(manager.unavailable.isEmpty)
    }

    @Test func firesTheHandlerWithTheComboThatWasPressed() {
        let registrar = FakeRegistrar()
        let manager = HotKeyManager(registrar: registrar, defaults: makeDefaults())
        var fired: [KeyCombo] = []
        manager.handlers[.main] = { fired.append($0) }
        manager.start()

        registrar.press(shiftCommandV)
        registrar.press(shiftCommandB) // no handler installed for snippets

        #expect(fired == [shiftCommandV])
    }

    @Test func changesPersistAcrossLaunches() {
        let defaults = makeDefaults()
        let first = HotKeyManager(registrar: FakeRegistrar(), defaults: defaults)
        first.start()
        #expect(first.set(controlOptionC, for: .main) == .ok)
        #expect(first.set(nil, for: .snippets) == .ok)

        let registrar = FakeRegistrar()
        let second = HotKeyManager(registrar: registrar, defaults: defaults)
        second.start()

        #expect(second.combos == [.main: controlOptionC, .search: controlCommandV], "a cleared shortcut must stay cleared, not fall back to its default")
        #expect(Set(registrar.registered.values) == [controlOptionC, controlCommandV])
    }

    @Test func refusesACombinationAnotherActionUses() {
        let registrar = FakeRegistrar()
        let manager = HotKeyManager(registrar: registrar, defaults: makeDefaults())
        manager.start()

        #expect(manager.set(shiftCommandB, for: .history) == .usedBy(.snippets))
        #expect(manager.combos[.history] == nil)
        #expect(manager.set(shiftCommandV, for: .main) == .ok, "re-recording the same combo for the same action is fine")
    }

    @Test func keepsTheOldShortcutWhenTheSystemRefusesTheNewOne() {
        let registrar = FakeRegistrar()
        registrar.refused = [controlOptionC]
        let manager = HotKeyManager(registrar: registrar, defaults: makeDefaults())
        manager.start()

        #expect(manager.set(controlOptionC, for: .main) == .unavailable)
        #expect(manager.combos[.main] == shiftCommandV)
        #expect(registrar.registered.values.contains(shiftCommandV))
    }

    @Test func reportsShortcutsTakenAtLaunch() {
        let registrar = FakeRegistrar()
        registrar.refused = [shiftCommandB]
        let manager = HotKeyManager(registrar: registrar, defaults: makeDefaults())
        manager.start()

        #expect(manager.unavailable == [.snippets])
    }

    @Test func pausingReleasesEveryShortcutAndResumingRestoresThem() {
        let registrar = FakeRegistrar()
        let manager = HotKeyManager(registrar: registrar, defaults: makeDefaults())
        manager.start()

        manager.pause()
        #expect(registrar.registered.isEmpty)

        // Recording happens while paused; the new combo takes effect on resume.
        #expect(manager.set(controlOptionC, for: .main) == .ok)
        #expect(registrar.registered.isEmpty)

        manager.resume()
        #expect(Set(registrar.registered.values) == [controlOptionC, shiftCommandB, controlCommandV])
    }

    @Test func restoreDefaultsForgetsCustomisation() {
        let defaults = makeDefaults()
        let registrar = FakeRegistrar()
        let manager = HotKeyManager(registrar: registrar, defaults: defaults)
        manager.start()
        _ = manager.set(controlOptionC, for: .main)
        _ = manager.set(nil, for: .snippets)

        manager.restoreDefaults()

        #expect(manager.combos == [.main: shiftCommandV, .snippets: shiftCommandB, .search: controlCommandV])
        #expect(Set(registrar.registered.values) == [shiftCommandV, shiftCommandB, controlCommandV])
        #expect(defaults.data(forKey: HotKeyAction.main.defaultsKey) == nil)
    }
}

struct KeyComboTests {
    @Test func convertsBetweenCocoaAndCarbonModifiers() {
        let combo = KeyCombo(keyCode: kVK_ANSI_V, modifiers: [.command, .shift, .capsLock])
        #expect(combo.carbonModifiers == UInt32(cmdKey | shiftKey))
        #expect(combo.modifiers == [.command, .shift])
    }

    @Test func displaysModifiersInMenuOrder() {
        let all = KeyCombo(keyCode: kVK_Space, modifiers: [.command, .shift, .option, .control])
        #expect(all.displayString == "⌃⌥⇧⌘Space")
        #expect(KeyCombo(keyCode: kVK_F5, modifiers: []).displayString == "F5")
        #expect(KeyCombo(keyCode: kVK_LeftArrow, modifiers: [.option]).displayString == "⌥←")
    }

    @Test func lettersFollowTheKeyboardLayout() throws {
        // Whatever the layout, the key found for "v" must display as "V".
        let keyCode = try #require(KeyboardLayout.keyCode(for: "v"))
        #expect(KeyCombo(keyCode: Int(keyCode), modifiers: [.command]).displayString == "⌘V")
    }

    @Test func recorderInterpretsKeyPresses() {
        #expect(RecorderInput(keyCode: kVK_Escape, modifiers: []) == .cancel)
        #expect(RecorderInput(keyCode: kVK_Delete, modifiers: []) == .clear)
        #expect(RecorderInput(keyCode: kVK_ANSI_V, modifiers: []) == .rejected)
        #expect(RecorderInput(keyCode: kVK_ANSI_V, modifiers: [.shift]) == .rejected, "⇧ alone would hijack typing")
        #expect(RecorderInput(keyCode: kVK_ANSI_V, modifiers: [.command, .shift])
            == .combo(KeyCombo(keyCode: kVK_ANSI_V, modifiers: [.command, .shift])))
        #expect(RecorderInput(keyCode: kVK_F6, modifiers: []) == .combo(KeyCombo(keyCode: kVK_F6, modifiers: [])))
        #expect(RecorderInput(keyCode: kVK_Escape, modifiers: [.command]) == .combo(KeyCombo(keyCode: kVK_Escape, modifiers: [.command])))
    }
}

struct LeftoverModifierTests {
    @Test func modifiersStillHeldFromTheShortcutAreIgnored() {
        // Opened with ⌃⌥C and still holding both: must not paste-and-delete.
        #expect(ClipAction(modifiers: [.control, .option], ignoring: [.control, .option]) == .paste)
        // ⌃ released and nothing else pressed.
        #expect(ClipAction(modifiers: [.option], ignoring: [.option]) == .paste)
    }

    @Test func freshlyPressedModifiersStillCount() {
        // Opened with ⇧⌘V, still holding ⌘, then deliberately pressed ⌥.
        #expect(ClipAction(modifiers: [.command, .option], ignoring: [.command]) == .pastePlainText)
        // Shortcut keys all released, then ⇧ pressed again on purpose.
        #expect(ClipAction(modifiers: [.shift], ignoring: []) == .togglePin)
    }
}

struct ExcludedAppListTests {
    @Test func addsWithoutDuplicatesOrItself() {
        let result = ExcludedAppList.adding(
            ["com.a", "com.b", "com.a", "com.alamin.Cowpy"],
            to: ["com.b"],
            ownBundleID: "com.alamin.Cowpy"
        )
        #expect(result == ["com.b", "com.a"])
    }
}
