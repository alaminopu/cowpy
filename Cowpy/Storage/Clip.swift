import Foundation
import SwiftData

/// One entry in the clipboard history.
///
/// Only the fields needed to draw the menu live inline; the pasteboard data
/// itself sits in `payload` (external storage) and is decoded on paste.
@Model
final class Clip {
    @Attribute(.unique) var contentHash: String
    var kindRaw: String
    var title: String
    /// Plain-text form, kept for search and tooltips.
    var text: String?
    var createdAt: Date
    var lastUsedAt: Date
    var sourceBundleID: String?
    var isPinned: Bool
    @Attribute(.externalStorage) var thumbnail: Data?
    @Attribute(.externalStorage) var payload: Data

    init(
        contentHash: String,
        kind: ClipKind,
        title: String,
        text: String?,
        date: Date,
        sourceBundleID: String?,
        thumbnail: Data?,
        payload: Data
    ) {
        self.contentHash = contentHash
        self.kindRaw = kind.rawValue
        self.title = title
        self.text = text
        self.createdAt = date
        self.lastUsedAt = date
        self.sourceBundleID = sourceBundleID
        self.isPinned = false
        self.thumbnail = thumbnail
        self.payload = payload
    }

    var kind: ClipKind { ClipKind(rawValue: kindRaw) ?? .text }
}
