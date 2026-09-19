import Foundation
import SwiftData

/// A named group of snippets; shows up as a submenu.
@Model
final class SnippetFolder {
    var title: String
    /// SwiftData relationships are unordered, so order is explicit.
    var sortIndex: Int
    var isEnabled: Bool
    @Relationship(deleteRule: .cascade, inverse: \Snippet.folder)
    var snippets: [Snippet]

    init(title: String, sortIndex: Int, isEnabled: Bool = true) {
        self.title = title
        self.sortIndex = sortIndex
        self.isEnabled = isEnabled
        self.snippets = []
    }

    var sortedSnippets: [Snippet] {
        snippets.sorted { $0.sortIndex < $1.sortIndex }
    }
}

/// A piece of text the user wrote once and pastes often.
@Model
final class Snippet {
    var title: String
    var content: String
    var sortIndex: Int
    var isEnabled: Bool
    var folder: SnippetFolder?

    init(title: String, content: String, sortIndex: Int, isEnabled: Bool = true) {
        self.title = title
        self.content = content
        self.sortIndex = sortIndex
        self.isEnabled = isEnabled
    }

    /// Falls back to the content so an untitled snippet is still recognisable in the menu.
    var menuTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? ClipContent.singleLine(content) : trimmed
    }
}
