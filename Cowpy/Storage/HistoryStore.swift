import Foundation
import OSLog
import SwiftData

/// Persistence for the clipboard history. All access happens on the main actor.
final class HistoryStore {
    /// Longest edge of stored thumbnails, in pixels (menu shows them at half size on Retina).
    static let thumbnailMaxPixelSize = 256

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let log = Logger(subsystem: "com.alamin.Cowpy", category: "HistoryStore")

    init(inMemory: Bool = false) throws {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            // Unsandboxed apps share ~/Library/Application Support, and SwiftData's
            // default "default.store" would collide with other apps there.
            let directory = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Cowpy", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            configuration = ModelConfiguration(url: directory.appendingPathComponent("History.store"))
        }
        container = try ModelContainer(for: Clip.self, configurations: configuration)
    }

    // MARK: - Reading

    /// Most recently used first.
    func recent(limit: Int? = nil) -> [Clip] {
        var descriptor = FetchDescriptor<Clip>(sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return fetch(descriptor)
    }

    /// Pinned clips in the order they were first copied, so their menu
    /// positions (and digit shortcuts) stay put as they get used.
    func pinned() -> [Clip] {
        fetch(FetchDescriptor<Clip>(
            predicate: #Predicate { $0.isPinned },
            sortBy: [SortDescriptor(\.createdAt)]
        ))
    }

    /// Unpinned clips, most recently used first.
    func unpinned(limit: Int? = nil) -> [Clip] {
        var descriptor = FetchDescriptor<Clip>(
            predicate: #Predicate { !$0.isPinned },
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return fetch(descriptor)
    }

    var count: Int {
        (try? context.fetchCount(FetchDescriptor<Clip>())) ?? 0
    }

    func content(of clip: Clip) -> ClipContent? {
        do {
            return try ClipContent(encoded: clip.payload)
        } catch {
            log.error("Could not decode clip payload: \(error)")
            return nil
        }
    }

    // MARK: - Writing

    /// Records new content, or moves the existing entry to the top if the same
    /// content was copied before.
    @discardableResult
    func add(_ content: ClipContent, sourceBundleID: String? = nil, date: Date = .now) -> Clip? {
        let hash = content.contentHash
        var descriptor = FetchDescriptor<Clip>(predicate: #Predicate { $0.contentHash == hash })
        descriptor.fetchLimit = 1

        if let existing = fetch(descriptor).first {
            existing.lastUsedAt = date
            save()
            return existing
        }

        let payload: Data
        do {
            payload = try content.encoded()
        } catch {
            log.error("Could not encode clip payload: \(error)")
            return nil
        }

        let clip = Clip(
            contentHash: hash,
            kind: content.kind,
            title: content.title,
            text: content.plainText,
            date: date,
            sourceBundleID: sourceBundleID,
            thumbnail: content.thumbnailPNG(maxPixelSize: Self.thumbnailMaxPixelSize),
            payload: payload
        )
        context.insert(clip)
        save()
        return clip
    }

    func touch(_ clip: Clip, date: Date = .now) {
        clip.lastUsedAt = date
        save()
    }

    func setPinned(_ isPinned: Bool, for clip: Clip) {
        clip.isPinned = isPinned
        save()
    }

    func delete(_ clip: Clip) {
        context.delete(clip)
        save()
    }

    /// Removes everything except pinned clips.
    func clear() {
        for clip in fetch(FetchDescriptor<Clip>(predicate: #Predicate { !$0.isPinned })) {
            context.delete(clip)
        }
        save()
    }

    /// Removes unpinned clips that were last used before `cutoff`.
    @discardableResult
    func removeExpired(before cutoff: Date) -> Int {
        let expired = fetch(FetchDescriptor<Clip>(
            predicate: #Predicate { !$0.isPinned && $0.lastUsedAt < cutoff }
        ))
        guard !expired.isEmpty else { return 0 }
        expired.forEach(context.delete)
        save()
        return expired.count
    }

    /// Drops the oldest unpinned clips until at most `maxCount` unpinned remain.
    func trim(to maxCount: Int) {
        var descriptor = FetchDescriptor<Clip>(
            predicate: #Predicate { !$0.isPinned },
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        descriptor.fetchOffset = max(0, maxCount)
        let overflow = fetch(descriptor)
        guard !overflow.isEmpty else { return }
        overflow.forEach(context.delete)
        save()
    }

    // MARK: - Helpers

    private func fetch(_ descriptor: FetchDescriptor<Clip>) -> [Clip] {
        do {
            return try context.fetch(descriptor)
        } catch {
            log.error("Fetch failed: \(error)")
            return []
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            log.error("Save failed: \(error)")
        }
    }
}
