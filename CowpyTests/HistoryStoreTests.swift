import Foundation
import Testing
@testable import Cowpy

struct HistoryStoreTests {
    private let base = Date(timeIntervalSinceReferenceDate: 0)

    @Test func newestClipComesFirst() throws {
        let store = try HistoryStore(inMemory: true)
        store.add(ClipContent(text: "one"), date: base)
        store.add(ClipContent(text: "two"), date: base.addingTimeInterval(1))

        #expect(store.recent().map(\.title) == ["two", "one"])
    }

    @Test func copyingTheSameThingAgainMovesItToTheTop() throws {
        let store = try HistoryStore(inMemory: true)
        store.add(ClipContent(text: "one"), date: base)
        store.add(ClipContent(text: "two"), date: base.addingTimeInterval(1))
        store.add(ClipContent(text: "one"), date: base.addingTimeInterval(2))

        #expect(store.count == 2)
        #expect(store.recent().map(\.title) == ["one", "two"])
    }

    @Test func trimDropsTheOldestUnpinnedClips() throws {
        let store = try HistoryStore(inMemory: true)
        for index in 0..<5 {
            store.add(ClipContent(text: "clip \(index)"), date: base.addingTimeInterval(Double(index)))
        }
        let oldest = try #require(store.recent().last)
        oldest.isPinned = true

        store.trim(to: 2)

        #expect(store.recent().map(\.title) == ["clip 4", "clip 3", "clip 0"])
    }

    @Test func clearKeepsPinnedClips() throws {
        let store = try HistoryStore(inMemory: true)
        store.add(ClipContent(text: "keep"), date: base)?.isPinned = true
        store.add(ClipContent(text: "drop"), date: base.addingTimeInterval(1))

        store.clear()

        #expect(store.recent().map(\.title) == ["keep"])
    }

    @Test func payloadRoundTrips() throws {
        let store = try HistoryStore(inMemory: true)
        let content = ClipContent(text: "moo")
        let clip = try #require(store.add(content, sourceBundleID: "com.example.app"))

        #expect(store.content(of: clip) == content)
        #expect(clip.sourceBundleID == "com.example.app")
        #expect(clip.kind == .text)
    }

    @Test func touchMovesClipToTheTop() throws {
        let store = try HistoryStore(inMemory: true)
        let first = try #require(store.add(ClipContent(text: "one"), date: base))
        store.add(ClipContent(text: "two"), date: base.addingTimeInterval(1))

        store.touch(first, date: base.addingTimeInterval(2))

        #expect(store.recent().first?.title == "one")
    }

    @Test func pinnedClipsKeepTheirOrderAndLeaveTheRecentList() throws {
        let store = try HistoryStore(inMemory: true)
        let a = try #require(store.add(ClipContent(text: "a"), date: base))
        let b = try #require(store.add(ClipContent(text: "b"), date: base.addingTimeInterval(1)))
        store.add(ClipContent(text: "c"), date: base.addingTimeInterval(2))

        store.setPinned(true, for: b)
        store.setPinned(true, for: a)
        // Using a pinned clip must not reshuffle the pinned section.
        store.touch(b, date: base.addingTimeInterval(10))

        #expect(store.pinned().map(\.title) == ["a", "b"])
        #expect(store.unpinned().map(\.title) == ["c"])

        store.setPinned(false, for: a)
        #expect(store.pinned().map(\.title) == ["b"])
        #expect(store.unpinned().map(\.title) == ["c", "a"])
    }

    @Test func expiryRemovesOldUnpinnedClipsOnly() throws {
        let store = try HistoryStore(inMemory: true)
        let oldPinned = try #require(store.add(ClipContent(text: "old pinned"), date: base))
        store.setPinned(true, for: oldPinned)
        store.add(ClipContent(text: "old"), date: base.addingTimeInterval(1))
        store.add(ClipContent(text: "fresh"), date: base.addingTimeInterval(100))

        let removed = store.removeExpired(before: base.addingTimeInterval(50))

        #expect(removed == 1)
        #expect(Set(store.recent().map(\.title)) == ["old pinned", "fresh"])
    }

    @Test func usingAClipResetsItsExpiry() throws {
        let store = try HistoryStore(inMemory: true)
        let clip = try #require(store.add(ClipContent(text: "reused"), date: base))
        store.touch(clip, date: base.addingTimeInterval(100))

        #expect(store.removeExpired(before: base.addingTimeInterval(50)) == 0)
    }
}
