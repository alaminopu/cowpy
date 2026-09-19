import Foundation
import Testing
@testable import Cowpy

struct SnippetStoreTests {
    @Test func foldersAndSnippetsKeepInsertionOrder() throws {
        let store = try SnippetStore(inMemory: true)
        let greetings = store.addFolder(title: "Greetings")
        store.addFolder(title: "Code")
        store.addSnippet(title: "Hi", content: "Hello there", to: greetings)
        store.addSnippet(title: "Bye", content: "See you", to: greetings)

        #expect(store.folders().map(\.title) == ["Greetings", "Code"])
        #expect(greetings.sortedSnippets.map(\.title) == ["Hi", "Bye"])
    }

    @Test func movingReordersAndRenumbers() throws {
        let store = try SnippetStore(inMemory: true)
        let folder = store.addFolder(title: "A")
        store.addFolder(title: "B")
        store.addFolder(title: "C")
        for title in ["1", "2", "3"] {
            store.addSnippet(title: title, to: folder)
        }

        store.moveFolders(fromOffsets: [2], toOffset: 0)
        store.moveSnippets(in: folder, fromOffsets: [0], toOffset: 3)

        #expect(store.folders().map(\.title) == ["C", "A", "B"])
        #expect(store.folders().map(\.sortIndex) == [0, 1, 2])
        #expect(folder.sortedSnippets.map(\.title) == ["2", "3", "1"])
    }

    @Test func menuHidesDisabledAndEmptyFolders() throws {
        let store = try SnippetStore(inMemory: true)
        let visible = store.addFolder(title: "Visible")
        store.addSnippet(title: "on", to: visible)
        store.addSnippet(title: "off", to: visible).isEnabled = false

        let disabled = store.addFolder(title: "Disabled")
        store.addSnippet(title: "x", to: disabled)
        disabled.isEnabled = false

        store.addFolder(title: "Empty")
        let allOff = store.addFolder(title: "All off")
        store.addSnippet(title: "y", to: allOff).isEnabled = false

        let menu = store.menuFolders()
        #expect(menu.map(\.folder.title) == ["Visible"])
        #expect(menu.first?.snippets.map(\.title) == ["on"])
    }

    @Test func deletingAFolderDeletesItsSnippets() throws {
        let store = try SnippetStore(inMemory: true)
        let folder = store.addFolder(title: "Doomed")
        store.addSnippet(title: "a", to: folder)
        let keeper = store.addFolder(title: "Keeper")
        store.addSnippet(title: "b", to: keeper)

        store.delete(folder)

        #expect(store.folders().map(\.title) == ["Keeper"])
        #expect(store.archive().flatMap(\.snippets).map(\.title) == ["b"])
    }

    @Test func importAppendsWithoutReplacing() throws {
        let store = try SnippetStore(inMemory: true)
        store.addSnippet(title: "mine", content: "keep me", to: store.addFolder(title: "Existing"))

        store.importFolders([.init(title: "Imported", snippets: [.init(title: "t", content: "c")])])

        #expect(store.archive() == [
            .init(title: "Existing", snippets: [.init(title: "mine", content: "keep me")]),
            .init(title: "Imported", snippets: [.init(title: "t", content: "c")]),
        ])
    }

    @Test func untitledSnippetsAreNamedAfterTheirContent() {
        #expect(Snippet(title: "  ", content: "line one\nline two", sortIndex: 0).menuTitle == "line one line two")
        #expect(Snippet(title: "Named", content: "whatever", sortIndex: 0).menuTitle == "Named")
    }
}

struct SnippetArchiveTests {
    private let sample: [SnippetArchive.Folder] = [
        .init(title: "Greetings & <Tags>", snippets: [
            .init(title: "Multi-line", content: "  Dear ,\n\n\tThanks!\n"),
            .init(title: "Unicode", content: "Moo 🐮 — ñ"),
            .init(title: "Empty", content: ""),
        ]),
        .init(title: "No snippets", snippets: []),
    ]

    @Test func roundTripsExactly() throws {
        let data = SnippetArchive.xmlData(for: sample)
        #expect(try SnippetArchive.folders(fromXML: data) == sample)
    }

    @Test func readsAClipyExport() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8" standalone="no"?>
        <folders>
        \t<folder>
        \t\t<title>Mail</title>
        \t\t<snippets>
        \t\t\t<snippet>
        \t\t\t\t<title>Sign-off</title>
        \t\t\t\t<content>Best,
        Al</content>
        \t\t\t</snippet>
        \t\t</snippets>
        \t</folder>
        </folders>
        """
        let folders = try SnippetArchive.folders(fromXML: Data(xml.utf8))
        #expect(folders == [.init(title: "Mail", snippets: [.init(title: "Sign-off", content: "Best,\nAl")])])
    }

    @Test func rejectsOtherXML() {
        #expect(throws: SnippetArchive.ArchiveError.self) {
            try SnippetArchive.folders(fromXML: Data("<plist><dict/></plist>".utf8))
        }
        #expect(throws: (any Error).self) {
            try SnippetArchive.folders(fromXML: Data("not xml at all".utf8))
        }
    }
}
