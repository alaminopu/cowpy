import AppKit
import SwiftUI
import Testing
@testable import Cowpy

/// Renders UI to PNGs for eyeballing. Skipped unless a destination is given:
///
///     TEST_RUNNER_COWPY_SNAPSHOT_DIR=/some/dir xcodebuild … test
@Suite(.serialized)
struct SnapshotTests {
    private nonisolated static let directory = ProcessInfo.processInfo.environment["COWPY_SNAPSHOT_DIR"]

    @Test(.enabled(if: directory != nil))
    func settingsPanes() throws {
        Defaults.register()
        try snapshot(GeneralSettingsView(), named: "settings-general")
        try snapshot(ShortcutsSettingsView(), named: "settings-shortcuts")
        try snapshot(MenuSettingsView(), named: "settings-menu")
        try snapshot(HistorySettingsView(), named: "settings-history")
        try snapshot(CaptureSettingsView(), named: "settings-capture")
    }

    @Test(.enabled(if: directory != nil))
    func colourSwatches() throws {
        let row = HStack(spacing: 12) {
            ForEach(["#ff8800", "#fff", "#000000", "rgba(0, 120, 255, 0.4)"], id: \.self) { value in
                if let color = ColorParser.parse(value) {
                    Label { Text(value) } icon: { Image(nsImage: ColorSwatch.image(for: color)) }
                }
            }
        }
        .padding()
        try snapshot(row, named: "swatches", size: NSSize(width: 520, height: 50))
    }

    @Test(.enabled(if: directory != nil))
    func snippetsEditor() throws {
        let store = try SnippetStore(inMemory: true)
        let mail = store.addFolder(title: "Mail")
        let signOff = store.addSnippet(title: "Sign-off", content: "Best regards,\nAl Amin\n\n-- \nSent with Cowpy 🐮", to: mail)
        store.addSnippet(title: "Out of office", content: "I am away until Monday.", to: mail)
        store.addSnippet(title: "Disabled one", content: "hidden", to: mail).isEnabled = false
        let code = store.addFolder(title: "Code")
        store.addSnippet(title: "", content: "console.log('moo')", to: code)

        let size = NSSize(width: 760, height: 480)
        try snapshot(
            SnippetsEditorView(store: store, initialSelection: .snippet(signOff.persistentModelID))
                .modelContainer(store.container),
            named: "snippets-snippet", size: size
        )
        try snapshot(
            SnippetsEditorView(store: store, initialSelection: .folder(code.persistentModelID))
                .modelContainer(store.container),
            named: "snippets-folder", size: size
        )
        try snapshot(
            SnippetsEditorView(store: try SnippetStore(inMemory: true)).modelContainer(try SnippetStore(inMemory: true).container),
            named: "snippets-empty", size: size
        )
    }

    private func snapshot(_ view: some View, named name: String, size: NSSize = NSSize(width: 500, height: 540)) throws {
        let directory = try #require(Self.directory)
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: -10_000, y: -10_000), size: size),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        // Windows made in code are released by ARC; the legacy close-releases default would double free.
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFrontRegardless()
        defer { window.close() }
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))

        let rep = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
    }
}
