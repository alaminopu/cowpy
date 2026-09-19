import AppKit
import Testing
@testable import Cowpy

struct ClipActionTests {
    @Test func noModifiersPastes() {
        #expect(ClipAction(modifiers: []) == .paste)
    }

    @Test func singleModifiersSelectTheirAction() {
        #expect(ClipAction(modifiers: [.option]) == .pastePlainText)
        #expect(ClipAction(modifiers: [.shift]) == .togglePin)
        #expect(ClipAction(modifiers: [.control]) == .delete)
        #expect(ClipAction(modifiers: [.control, .option]) == .pasteAndDelete)
    }

    /// The history opens with ⇧⌘V; keys still held from that must not do anything surprising.
    @Test func leftoverHotkeyModifiersJustPaste() {
        #expect(ClipAction(modifiers: [.command, .shift]) == .paste)
        #expect(ClipAction(modifiers: [.command]) == .paste)
    }

    @Test func unrelatedFlagsAreIgnored() {
        #expect(ClipAction(modifiers: [.capsLock, .function, .numericPad]) == .paste)
        #expect(ClipAction(modifiers: [.option, .capsLock]) == .pastePlainText)
    }

    @Test func unknownCombinationsFallBackToPaste() {
        #expect(ClipAction(modifiers: [.control, .shift]) == .paste)
        #expect(ClipAction(modifiers: [.command, .control]) == .paste)
    }

    @Test func removingActionsNeverInvolveHotkeyModifiers() {
        for action in [ClipAction.delete, .pasteAndDelete] {
            let symbols = action.modifierSymbols ?? ""
            #expect(!symbols.contains("⌘") && !symbols.contains("⇧"))
        }
    }
}

struct ColorParserTests {
    @Test func parsesSixDigitHex() {
        #expect(ColorParser.parse("#ff8000") == .init(red: 1, green: 128.0 / 255, blue: 0))
        #expect(ColorParser.parse("  #FF8000\n") == .init(red: 1, green: 128.0 / 255, blue: 0))
    }

    @Test func parsesShorthandAndAlphaHex() {
        #expect(ColorParser.parse("#f80") == ColorParser.parse("#ff8800"))
        #expect(ColorParser.parse("#f808") == ColorParser.parse("#ff880088"))
        #expect(ColorParser.parse("#00000080")?.alpha == 128.0 / 255)
    }

    @Test func parsesFunctionalNotation() {
        let orange = ColorParser.RGBA(red: 1, green: 136.0 / 255, blue: 0)
        #expect(ColorParser.parse("rgb(255, 136, 0)") == orange)
        #expect(ColorParser.parse("RGB(255,136,0)") == orange)
        #expect(ColorParser.parse("rgb(255 136 0)") == orange)
        #expect(ColorParser.parse("rgba(255, 136, 0, 0.5)")?.alpha == 0.5)
        #expect(ColorParser.parse("rgb(255 136 0 / 50%)")?.alpha == 0.5)
    }

    @Test func rejectsThingsThatAreNotColours() {
        #expect(ColorParser.parse("123456") == nil, "bare digits are usually one-time codes")
        #expect(ColorParser.parse("facade") == nil)
        #expect(ColorParser.parse("#12") == nil)
        #expect(ColorParser.parse("#12345") == nil)
        #expect(ColorParser.parse("#ggg") == nil)
        #expect(ColorParser.parse("#fff is white") == nil)
        #expect(ColorParser.parse("rgb(256, 0, 0)") == nil)
        #expect(ColorParser.parse("rgb(1, 2)") == nil)
        #expect(ColorParser.parse("rgba(1, 2, 3, 2)") == nil)
        #expect(ColorParser.parse("") == nil)
    }

    @Test func swatchHasRequestedSize() {
        let image = ColorSwatch.image(for: .init(red: 1, green: 0, blue: 0), side: 14)
        #expect(image.size == NSSize(width: 14, height: 14))
    }
}

struct HistoryRetentionTests {
    @Test func foreverNeverExpires() {
        #expect(HistoryRetention.forever.cutoff() == nil)
    }

    @Test func cutoffIsRetentionBeforeNow() {
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        #expect(HistoryRetention.oneHour.cutoff(from: now) == now.addingTimeInterval(-3600))
        #expect(HistoryRetention.oneDay.cutoff(from: now) == now.addingTimeInterval(-86400))
    }
}
