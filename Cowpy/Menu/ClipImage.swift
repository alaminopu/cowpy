import AppKit

/// The small image shown next to a clip, in menus and in the search panel.
enum ClipImage {
    static func image(for clip: Clip, store: HistoryStore) -> NSImage? {
        switch clip.kind {
        case .image:
            guard Defaults.showsThumbnails, let data = clip.thumbnail, let image = NSImage(data: data) else {
                return nil
            }
            // Thumbnails are stored at 2x; cap the on-screen height to keep rows compact.
            let maxHeight: CGFloat = 36
            let scale = min(1, maxHeight / max(image.size.height, 1), 120 / max(image.size.width, 1))
            image.size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            return image
        case .files:
            guard let path = store.content(of: clip)?.fileURLs.first?.path else { return nil }
            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 16, height: 16)
            return icon
        case .text, .richText, .url:
            guard Defaults.showsColorSwatches, let text = clip.text, let color = ColorParser.parse(text) else {
                return nil
            }
            return ColorSwatch.image(for: color)
        case .pdf:
            return nil
        }
    }

    /// Fallback symbol for clips that have no image of their own.
    static func symbolName(for kind: ClipKind) -> String {
        switch kind {
        case .text: "text.alignleft"
        case .richText: "textformat"
        case .url: "link"
        case .image: "photo"
        case .pdf: "doc.richtext"
        case .files: "doc"
        }
    }
}
