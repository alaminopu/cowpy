import Foundation
import OSLog
import SwiftData

/// Persistence for snippets.
///
/// Snippets live in their own database, apart from the clipboard history:
/// history is disposable, snippets are things the user wrote, and nothing that
/// clears or migrates one should be able to damage the other.
final class SnippetStore {
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let log = Logger(subsystem: "com.alamin.Cowpy", category: "SnippetStore")

    init(inMemory: Bool = false) throws {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration("Snippets", isStoredInMemoryOnly: true)
        } else {
            let directory = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Cowpy", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            configuration = ModelConfiguration("Snippets", url: directory.appendingPathComponent("Snippets.store"))
        }
        container = try ModelContainer(for: SnippetFolder.self, Snippet.self, configurations: configuration)
    }

    // MARK: - Reading

    func folders() -> [SnippetFolder] {
        do {
            return try context.fetch(FetchDescriptor<SnippetFolder>(sortBy: [SortDescriptor(\.sortIndex)]))
        } catch {
            log.error("Fetch failed: \(error)")
            return []
        }
    }

    /// What the menus show: enabled folders that still have enabled snippets.
    func menuFolders() -> [(folder: SnippetFolder, snippets: [Snippet])] {
        folders().compactMap { folder in
            guard folder.isEnabled else { return nil }
            let snippets = folder.sortedSnippets.filter(\.isEnabled)
            return snippets.isEmpty ? nil : (folder, snippets)
        }
    }

    // MARK: - Writing

    @discardableResult
    func addFolder(title: String = "Untitled Folder") -> SnippetFolder {
        let folder = SnippetFolder(title: title, sortIndex: (folders().last?.sortIndex ?? -1) + 1)
        context.insert(folder)
        save()
        return folder
    }

    @discardableResult
    func addSnippet(title: String = "Untitled Snippet", content: String = "", to folder: SnippetFolder) -> Snippet {
        let snippet = Snippet(
            title: title,
            content: content,
            sortIndex: (folder.sortedSnippets.last?.sortIndex ?? -1) + 1
        )
        context.insert(snippet)
        snippet.folder = folder
        save()
        return snippet
    }

    func delete(_ folder: SnippetFolder) {
        context.delete(folder)
        save()
    }

    func delete(_ snippet: Snippet) {
        context.delete(snippet)
        save()
    }

    func moveFolders(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = folders()
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, folder) in ordered.enumerated() {
            folder.sortIndex = index
        }
        save()
    }

    func moveSnippets(in folder: SnippetFolder, fromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = folder.sortedSnippets
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, snippet) in ordered.enumerated() {
            snippet.sortIndex = index
        }
        save()
    }

    /// Appends imported folders after the existing ones; nothing is replaced.
    func importFolders(_ archive: [SnippetArchive.Folder]) {
        for archived in archive {
            let folder = addFolder(title: archived.title)
            for archivedSnippet in archived.snippets {
                addSnippet(title: archivedSnippet.title, content: archivedSnippet.content, to: folder)
            }
        }
    }

    func archive() -> [SnippetArchive.Folder] {
        folders().map { folder in
            SnippetArchive.Folder(
                title: folder.title,
                snippets: folder.sortedSnippets.map { .init(title: $0.title, content: $0.content) }
            )
        }
    }

    func save() {
        do {
            try context.save()
        } catch {
            log.error("Save failed: \(error)")
        }
    }
}
