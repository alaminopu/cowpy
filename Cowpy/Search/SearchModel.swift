import AppKit
import Observation
import SwiftData

/// One row in the search panel.
enum SearchResult: Identifiable, Equatable {
    case clip(Clip)
    case snippet(Snippet)

    /// Clips and snippets live in different stores, so their identifiers never collide.
    var id: PersistentIdentifier {
        switch self {
        case .clip(let clip): clip.persistentModelID
        case .snippet(let snippet): snippet.persistentModelID
        }
    }

    var title: String {
        switch self {
        case .clip(let clip): clip.title
        case .snippet(let snippet): snippet.menuTitle
        }
    }

    /// Everything the query is matched against.
    var searchableText: String {
        switch self {
        case .clip(let clip): clip.title + "\n" + (clip.text ?? "")
        case .snippet(let snippet): snippet.title + "\n" + snippet.content
        }
    }

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

/// State behind the search panel: the query, the filtered rows and the selection.
@Observable
final class SearchModel {
    /// Enough to scroll through comfortably; a longer list means the query needs narrowing.
    static let maxResults = 200

    var query = "" {
        didSet { if query != oldValue { refilter() } }
    }
    private(set) var results: [SearchResult] = []
    private(set) var selectedIndex = 0
    /// Changes every time the panel opens, so the view can reset focus and scroll position.
    private(set) var sessionID = UUID()

    @ObservationIgnored private let store: HistoryStore
    @ObservationIgnored private let snippetStore: SnippetStore
    @ObservationIgnored private var candidates: [SearchResult] = []

    init(store: HistoryStore, snippetStore: SnippetStore) {
        self.store = store
        self.snippetStore = snippetStore
    }

    var selection: SearchResult? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    /// Call when the panel opens.
    func beginSession() {
        sessionID = UUID()
        query = ""
        reload()
        selectedIndex = 0
    }

    /// Re-reads clips and snippets, keeping the selection in place where possible.
    func reload() {
        let clips = store.pinned() + store.unpinned(limit: Defaults.maxHistorySize)
        let snippets = snippetStore.menuFolders().flatMap(\.snippets)
        candidates = clips.map(SearchResult.clip) + snippets.map(SearchResult.snippet)
        refilter(keepingSelection: true)
    }

    func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + offset, 0), results.count - 1)
    }

    func select(_ result: SearchResult) {
        if let index = results.firstIndex(of: result) {
            selectedIndex = index
        }
    }

    func image(for clip: Clip) -> NSImage? {
        ClipImage.image(for: clip, store: store)
    }

    private func refilter(keepingSelection: Bool = false) {
        let previous = keepingSelection ? selectedIndex : 0
        results = Array(
            candidates.lazy
                .filter { SearchFilter.matches(self.query, in: $0.searchableText) }
                .prefix(Self.maxResults)
        )
        selectedIndex = results.isEmpty ? 0 : min(previous, results.count - 1)
    }
}
