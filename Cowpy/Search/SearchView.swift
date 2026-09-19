import SwiftUI

/// Search field over a list of clips and snippets.
///
/// Arrow keys, Return and Escape are handled by `SearchPanelController` (an
/// AppKit key monitor), so the text field only ever deals with text.
struct SearchView: View {
    @Bindable var model: SearchModel
    var onChoose: (SearchResult) -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            if model.results.isEmpty {
                emptyState
            } else {
                resultList
            }
            Divider()
            footer
        }
        .frame(width: 580, height: 420)
        .background(.regularMaterial)
        // A new identity per session resets focus and scroll position.
        .id(model.sessionID)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            TextField("Search clips and snippets", text: $model.query)
                .textFieldStyle(.plain)
                .font(.title2)
                .focused($isSearchFocused)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .onAppear { isSearchFocused = true }
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                        SearchResultRow(
                            result: result,
                            image: clipImage(for: result),
                            quickPickNumber: index < 9 ? index + 1 : nil,
                            isSelected: index == model.selectedIndex
                        )
                        .id(result.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.select(result)
                            onChoose(result)
                        }
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selectedIndex) {
                if let id = model.selection?.id {
                    proxy.scrollTo(id)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(model.query.isEmpty ? "Nothing copied yet" : "No matches", systemImage: "magnifyingglass")
        } description: {
            Text(model.query.isEmpty ? "Copy something and it will show up here." : "Nothing matches “\(model.query)”.")
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text("↩ Paste")
            Text("⌥↩ Plain text")
            Text("⇧↩ Pin")
            Text("⌃↩ Remove")
            Text("⌘1–9 Quick paste")
            Spacer()
            Text("\(model.results.count) shown")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private func clipImage(for result: SearchResult) -> NSImage? {
        if case .clip(let clip) = result {
            return model.image(for: clip)
        }
        return nil
    }
}

private struct SearchResultRow: View {
    let result: SearchResult
    let image: NSImage?
    let quickPickNumber: Int?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            icon
                .frame(width: 28, alignment: .center)

            Text(result.title)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            if isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
            }
            if let quickPickNumber {
                Text("⌘\(quickPickNumber)")
                    .font(.caption.monospaced())
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.tertiary))
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 30)
        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.clear))
        )
    }

    @ViewBuilder
    private var icon: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 28, maxHeight: 22)
        } else {
            Image(systemName: symbolName)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
        }
    }

    private var symbolName: String {
        switch result {
        case .clip(let clip): ClipImage.symbolName(for: clip.kind)
        case .snippet: "text.badge.star"
        }
    }

    private var isPinned: Bool {
        if case .clip(let clip) = result { return clip.isPinned }
        return false
    }
}
