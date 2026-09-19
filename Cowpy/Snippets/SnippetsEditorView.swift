import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Two-pane editor: folders and their snippets on the left, the selected item on the right.
struct SnippetsEditorView: View {
    enum Selection: Hashable {
        case folder(PersistentIdentifier)
        case snippet(PersistentIdentifier)
    }

    let store: SnippetStore

    @Query(sort: \SnippetFolder.sortIndex) private var folders: [SnippetFolder]
    @State private var selection: Selection?
    @State private var folderPendingDeletion: SnippetFolder?
    @State private var errorMessage: String?

    init(store: SnippetStore, initialSelection: Selection? = nil) {
        self.store = store
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        // A plain split view rather than NavigationSplitView: this window is a
        // utility editor, and the navigation sidebar's toolbar and material
        // treatment add nothing here.
        HSplitView {
            sidebar
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 360)
            detail
                .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 680, minHeight: 420)
        .confirmationDialog(
            "Delete “\(folderPendingDeletion?.title ?? "")” and its \(folderPendingDeletion?.snippets.count ?? 0) snippets?",
            isPresented: Binding(
                get: { folderPendingDeletion != nil },
                set: { if !$0 { folderPendingDeletion = nil } }
            )
        ) {
            Button("Delete Folder", role: .destructive) {
                if let folder = folderPendingDeletion {
                    delete(folder)
                }
            }
        }
        .alert("Snippets", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(folders) { folder in
                Label(folder.title.isEmpty ? "Untitled Folder" : folder.title, systemImage: "folder")
                    .fontWeight(.medium)
                    .opacity(folder.isEnabled ? 1 : 0.45)
                    .tag(Selection.folder(folder.persistentModelID))
                    .contextMenu { folderContextMenu(folder) }

                ForEach(folder.sortedSnippets) { snippet in
                    Label(snippet.menuTitle.isEmpty ? "Untitled Snippet" : snippet.menuTitle, systemImage: "doc.text")
                        .lineLimit(1)
                        .padding(.leading, 14)
                        .opacity(folder.isEnabled && snippet.isEnabled ? 1 : 0.45)
                        .tag(Selection.snippet(snippet.persistentModelID))
                }
                .onMove { source, destination in
                    store.moveSnippets(in: folder, fromOffsets: source, toOffset: destination)
                }
            }
        }
        .listStyle(.inset)
        .overlay {
            if folders.isEmpty {
                ContentUnavailableView(
                    "No Snippets",
                    systemImage: "text.badge.plus",
                    description: Text("Add a folder, then add the text you paste again and again.")
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { sidebarBar }
    }

    private var sidebarBar: some View {
        HStack(spacing: 14) {
            Button(action: addFolder) {
                Label("Add Folder", systemImage: "folder.badge.plus")
            }
            .help("Add a folder")

            Button(action: addSnippet) {
                Label("Add Snippet", systemImage: "plus")
            }
            .help("Add a snippet to the selected folder")
            .disabled(selectedFolder == nil)

            Button(action: deleteSelection) {
                Label("Delete", systemImage: "minus")
            }
            .help("Delete the selected item")
            .disabled(selection == nil)

            Spacer()

            Menu {
                Button("Import…", action: importSnippets)
                Button("Export…", action: exportSnippets)
                    .disabled(folders.isEmpty)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Import or export snippets (Clipy-compatible XML)")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder
    private func folderContextMenu(_ folder: SnippetFolder) -> some View {
        let index = folders.firstIndex(of: folder) ?? 0
        Button("Move Up") {
            store.moveFolders(fromOffsets: [index], toOffset: index - 1)
        }
        .disabled(index == 0)
        Button("Move Down") {
            store.moveFolders(fromOffsets: [index], toOffset: index + 2)
        }
        .disabled(index >= folders.count - 1)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .snippet(let id):
            if let snippet = snippet(with: id) {
                SnippetDetailView(snippet: snippet)
            } else {
                placeholder
            }
        case .folder(let id):
            if let folder = folder(with: id) {
                FolderDetailView(folder: folder)
            } else {
                placeholder
            }
        case nil:
            placeholder
        }
    }

    private var placeholder: some View {
        Text(folders.isEmpty ? "Add a folder to get started" : "Select a folder or snippet")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Lookup

    private func folder(with id: PersistentIdentifier) -> SnippetFolder? {
        folders.first { $0.persistentModelID == id }
    }

    private func snippet(with id: PersistentIdentifier) -> Snippet? {
        folders.lazy.flatMap(\.snippets).first { $0.persistentModelID == id }
    }

    /// The folder new snippets go into: the selected one, or the selected snippet's.
    private var selectedFolder: SnippetFolder? {
        switch selection {
        case .folder(let id): folder(with: id)
        case .snippet(let id): snippet(with: id)?.folder
        case nil: nil
        }
    }

    // MARK: - Actions

    private func addFolder() {
        let folder = store.addFolder()
        selection = .folder(folder.persistentModelID)
    }

    private func addSnippet() {
        guard let folder = selectedFolder else { return }
        let snippet = store.addSnippet(to: folder)
        selection = .snippet(snippet.persistentModelID)
    }

    private func deleteSelection() {
        switch selection {
        case .snippet(let id):
            guard let snippet = snippet(with: id) else { return }
            let folderID = snippet.folder?.persistentModelID
            store.delete(snippet)
            selection = folderID.map(Selection.folder)
        case .folder(let id):
            guard let folder = folder(with: id) else { return }
            if folder.snippets.isEmpty {
                delete(folder)
            } else {
                folderPendingDeletion = folder
            }
        case nil:
            break
        }
    }

    private func delete(_ folder: SnippetFolder) {
        store.delete(folder)
        selection = nil
        folderPendingDeletion = nil
    }

    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.xml]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a snippet export from Cowpy or Clipy."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let imported = try SnippetArchive.folders(fromXML: Data(contentsOf: url))
            guard !imported.isEmpty else {
                errorMessage = "That file contains no snippet folders."
                return
            }
            store.importFolders(imported)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportSnippets() {
        store.save()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.xml]
        panel.nameFieldStringValue = "snippets.xml"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try SnippetArchive.xmlData(for: store.archive()).write(to: url, options: .atomic)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Detail panes

private struct SnippetDetailView: View {
    @Bindable var snippet: Snippet

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $snippet.title, prompt: Text("Title shown in the menu"))
                .textFieldStyle(.roundedBorder)
                .font(.title3)

            TextEditor(text: $snippet.content)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))

            HStack {
                Toggle("Show in menu", isOn: $snippet.isEnabled)
                Spacer()
                Text("\(snippet.content.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}

private struct FolderDetailView: View {
    @Bindable var folder: SnippetFolder

    var body: some View {
        Form {
            TextField("Folder name", text: $folder.title)
            Toggle("Show in menu", isOn: $folder.isEnabled)
            LabeledContent("Snippets", value: "\(folder.snippets.count)")
        }
        .formStyle(.grouped)
    }
}
