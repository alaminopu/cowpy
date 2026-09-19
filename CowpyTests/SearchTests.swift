import AppKit
import Carbon.HIToolbox
import Testing
@testable import Cowpy

struct SearchFilterTests {
    @Test func emptyQueryMatchesEverything() {
        #expect(SearchFilter.matches("", in: "anything"))
        #expect(SearchFilter.matches("   ", in: ""))
    }

    @Test func everyTermMustAppearInAnyOrder() {
        #expect(SearchFilter.matches("moo cafe", in: "A café where cows go MOO"))
        #expect(!SearchFilter.matches("moo horse", in: "A café where cows go MOO"))
    }

    @Test func ignoresCaseAccentsAndWidth() {
        #expect(SearchFilter.matches("CAFE", in: "café"))
        #expect(SearchFilter.matches("naïve", in: "NAIVE approach"))
        #expect(SearchFilter.matches("abc", in: "ＡＢＣ full-width"))
    }

    @Test func matchesAcrossLines() {
        #expect(SearchFilter.matches("second", in: "first line\nsecond line"))
    }
}

struct SearchModelTests {
    private let base = Date(timeIntervalSinceReferenceDate: 0)

    private func makeModel() throws -> (SearchModel, HistoryStore, SnippetStore) {
        // The app delegate skips start-up under test, so the history size limit
        // the model reads would otherwise be unset.
        Defaults.register()
        let store = try HistoryStore(inMemory: true)
        let snippets = try SnippetStore(inMemory: true)
        store.add(ClipContent(text: "git commit --amend"), date: base)
        store.add(ClipContent(text: "https://example.com/moo"), date: base.addingTimeInterval(1))
        let pinned = try #require(store.add(ClipContent(text: "pinned address"), date: base.addingTimeInterval(2)))
        store.setPinned(true, for: pinned)
        store.add(ClipContent(text: "newest clip"), date: base.addingTimeInterval(3))

        let folder = snippets.addFolder(title: "Mail")
        snippets.addSnippet(title: "Sign-off", content: "Best regards, the commit cow", to: folder)
        snippets.addSnippet(title: "Hidden", content: "commit", to: folder).isEnabled = false

        let model = SearchModel(store: store, snippetStore: snippets)
        model.beginSession()
        return (model, store, snippets)
    }

    @Test func listsPinnedThenRecentThenSnippets() throws {
        let (model, _, _) = try makeModel()
        #expect(model.results.map(\.title) == [
            "pinned address", "newest clip", "https://example.com/moo", "git commit --amend", "Sign-off",
        ])
        #expect(model.selection?.title == "pinned address")
    }

    @Test func filtersClipsAndEnabledSnippetsByContent() throws {
        let (model, _, _) = try makeModel()
        model.query = "commit"
        #expect(model.results.map(\.title) == ["git commit --amend", "Sign-off"])
    }

    @Test func selectionStaysInBounds() throws {
        let (model, _, _) = try makeModel()
        model.moveSelection(by: -5)
        #expect(model.selectedIndex == 0)
        model.moveSelection(by: 100)
        #expect(model.selectedIndex == model.results.count - 1)

        model.query = "moo" // narrowing resets to the best match
        #expect(model.selectedIndex == 0)
        model.query = "no such thing"
        #expect(model.selection == nil)
        model.moveSelection(by: 1) // must not crash on an empty list
    }

    @Test func reloadAfterDeletingKeepsTheCursorNearby() throws {
        let (model, store, _) = try makeModel()
        model.moveSelection(by: 1)
        guard case .clip(let clip) = try #require(model.selection) else {
            Issue.record("expected a clip")
            return
        }

        store.delete(clip)
        model.reload()

        #expect(model.selectedIndex == 1)
        #expect(model.selection?.title == "https://example.com/moo")
    }

    @Test func aNewSessionClearsTheQuery() throws {
        let (model, _, _) = try makeModel()
        let firstSession = model.sessionID
        model.query = "moo"
        model.moveSelection(by: 1)

        model.beginSession()

        #expect(model.query.isEmpty)
        #expect(model.selectedIndex == 0)
        #expect(model.results.count == 5)
        #expect(model.sessionID != firstSession)
    }
}

struct SearchKeyTests {
    @Test func navigationKeys() {
        #expect(SearchKey(keyCode: kVK_UpArrow, characters: nil, modifiers: [.function, .numericPad]) == .move(-1))
        #expect(SearchKey(keyCode: kVK_DownArrow, characters: nil, modifiers: []) == .move(1))
        #expect(SearchKey(keyCode: kVK_PageDown, characters: nil, modifiers: []) == .move(8))
        #expect(SearchKey(keyCode: kVK_Return, characters: "\r", modifiers: [.option]) == .choose)
        #expect(SearchKey(keyCode: kVK_Escape, characters: nil, modifiers: []) == .escape)
    }

    @Test func commandDigitsQuickPick() {
        #expect(SearchKey(keyCode: kVK_ANSI_1, characters: "1", modifiers: [.command]) == .quickPick(0))
        #expect(SearchKey(keyCode: kVK_ANSI_9, characters: "9", modifiers: [.command]) == .quickPick(8))
        #expect(SearchKey(keyCode: kVK_ANSI_0, characters: "0", modifiers: [.command]) == .text)
    }

    @Test func ordinaryTypingReachesTheTextField() {
        #expect(SearchKey(keyCode: kVK_ANSI_1, characters: "1", modifiers: []) == .text)
        #expect(SearchKey(keyCode: kVK_ANSI_A, characters: "a", modifiers: [.command]) == .text, "⌘A must still select all")
        #expect(SearchKey(keyCode: kVK_ANSI_1, characters: "1", modifiers: [.command, .shift]) == .text)
    }
}
