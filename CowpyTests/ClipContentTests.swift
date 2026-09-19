import AppKit
import Testing
@testable import Cowpy

struct ClipContentTests {
    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: .init("com.alamin.CowpyTests.\(UUID().uuidString)"))
    }

    @Test func readsPlainTextFromPasteboard() throws {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("hello moo", forType: .string)

        let content = try #require(ClipContent(pasteboard: pasteboard))
        #expect(content.plainText == "hello moo")
        #expect(content.kind == .text)
        #expect(content.title == "hello moo")
    }

    @Test func emptyPasteboardProducesNothing() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()

        #expect(ClipContent(pasteboard: pasteboard) == nil)
    }

    @Test func skipsConcealedContentWhenAsked() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.declareTypes([.string, .init("org.nspasteboard.ConcealedType")], owner: nil)
        pasteboard.setString("hunter2", forType: .string)

        #expect(ClipContent(pasteboard: pasteboard, ignoringConcealed: true) == nil)
        #expect(ClipContent(pasteboard: pasteboard, ignoringConcealed: false)?.plainText == "hunter2")
    }

    @Test func roundTripsThroughPasteboard() throws {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        let original = ClipContent(representations: [
            .init(type: NSPasteboard.PasteboardType.string.rawValue, data: Data("bold".utf8)),
            .init(type: NSPasteboard.PasteboardType.rtf.rawValue, data: Data(#"{\rtf1 \b bold}"#.utf8)),
        ])

        original.write(to: pasteboard)
        let readBack = try #require(ClipContent(pasteboard: pasteboard))

        #expect(readBack == original)
        #expect(readBack.contentHash == original.contentHash)
        #expect(readBack.kind == .richText)
    }

    @Test func plainTextOnlyWriteDropsFormatting() throws {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        let rich = ClipContent(representations: [
            .init(type: NSPasteboard.PasteboardType.string.rawValue, data: Data("bold".utf8)),
            .init(type: NSPasteboard.PasteboardType.rtf.rawValue, data: Data(#"{\rtf1 \b bold}"#.utf8)),
        ])

        rich.write(to: pasteboard, plainTextOnly: true)

        #expect(pasteboard.data(forType: .rtf) == nil)
        #expect(pasteboard.string(forType: .string) == "bold")
    }

    @Test func titleCollapsesWhitespaceToOneLine() {
        let content = ClipContent(text: "  first line\n\tsecond   line \n")
        #expect(content.title == "first line second line")
    }

    @Test func detectsWebURLs() {
        #expect(ClipContent(text: "https://example.com/moo?x=1").kind == .url)
        #expect(ClipContent(text: "see https://example.com").kind == .text)
        #expect(ClipContent(text: "mailto:cow@example.com").kind == .text)
    }

    @Test func fileCopiesAreTitledByName() {
        let one = ClipContent(fileURLs: [URL(fileURLWithPath: "/tmp/a.txt")])
        let two = ClipContent(fileURLs: [URL(fileURLWithPath: "/tmp/a.txt"), URL(fileURLWithPath: "/tmp/b.txt")])

        #expect(one.kind == .files)
        #expect(one.title == "a.txt")
        #expect(two.title == "2 files: a.txt, b.txt")
    }

    @Test func hashDependsOnContent() {
        #expect(ClipContent(text: "a").contentHash == ClipContent(text: "a").contentHash)
        #expect(ClipContent(text: "a").contentHash != ClipContent(text: "b").contentHash)
    }

    @Test func survivesEncoding() throws {
        let content = ClipContent(
            representations: [.init(type: "public.utf8-plain-text", data: Data("x".utf8))],
            fileURLs: []
        )
        #expect(try ClipContent(encoded: content.encoded()) == content)
    }

    @Test func buildsThumbnailForImages() throws {
        let image = NSImage(size: NSSize(width: 400, height: 200), flipped: false) { rect in
            NSColor.systemPink.setFill()
            rect.fill()
            return true
        }
        let tiff = try #require(image.tiffRepresentation)
        let content = ClipContent(representations: [.init(type: NSPasteboard.PasteboardType.tiff.rawValue, data: tiff)])

        #expect(content.kind == .image)
        let thumbnail = try #require(content.thumbnailPNG(maxPixelSize: 64))
        let rep = try #require(NSBitmapImageRep(data: thumbnail))
        #expect(max(rep.pixelsWide, rep.pixelsHigh) == 64)
    }

    // MARK: - Capture options

    private func richPasteboard() -> NSPasteboard {
        let pasteboard = makePasteboard()
        ClipContent(representations: [
            .init(type: NSPasteboard.PasteboardType.string.rawValue, data: Data("bold".utf8)),
            .init(type: NSPasteboard.PasteboardType.rtf.rawValue, data: Data(#"{\rtf1 \b bold}"#.utf8)),
        ]).write(to: pasteboard)
        return pasteboard
    }

    @Test func formattingCanBeLeftOut() throws {
        let pasteboard = richPasteboard()
        defer { pasteboard.releaseGlobally() }

        let content = try #require(ClipContent(pasteboard: pasteboard, capturing: [.text]))
        #expect(content.kind == .text)
        #expect(content.representations.map(\.type) == [NSPasteboard.PasteboardType.string.rawValue])
    }

    @Test func formattingAloneIsNotRecordedWithoutText() {
        let pasteboard = richPasteboard()
        defer { pasteboard.releaseGlobally() }

        #expect(ClipContent(pasteboard: pasteboard, capturing: [.richText, .images]) == nil)
    }

    @Test func disabledFileCaptureDropsFileCopiesEntirely() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/a.txt") as NSURL])

        #expect(ClipContent(pasteboard: pasteboard)?.kind == .files)
        #expect(ClipContent(pasteboard: pasteboard, capturing: CaptureOptions.all.subtracting(.files)) == nil)
    }

    @Test func disabledImageCaptureDropsImages() throws {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        let image = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        ClipContent(representations: [
            .init(type: NSPasteboard.PasteboardType.tiff.rawValue, data: try #require(image.tiffRepresentation)),
        ]).write(to: pasteboard)

        #expect(ClipContent(pasteboard: pasteboard)?.kind == .image)
        #expect(ClipContent(pasteboard: pasteboard, capturing: [.text, .richText]) == nil)
    }
}
