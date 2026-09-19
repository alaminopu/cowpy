import AppKit

/// Watches the general pasteboard for changes.
///
/// macOS has no pasteboard change notification, so this polls `changeCount`,
/// which is cheap (no pasteboard contents are read unless the count moved).
final class ClipboardMonitor {
    /// Called with the new content and the bundle identifier of the frontmost app.
    var onNewContent: ((ClipContent, String?) -> Void)?

    private let pasteboard: NSPasteboard
    private let interval: TimeInterval
    private var lastChangeCount: Int
    private var timer: Timer?

    init(pasteboard: NSPasteboard = .general, interval: TimeInterval = 0.5) {
        self.pasteboard = pasteboard
        self.interval = interval
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = interval / 5
        // `.common` keeps the timer firing while a menu is being tracked.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call right after Cowpy itself writes to the pasteboard so the write is
    /// not recorded as a new clip.
    func ignoreCurrentChange() {
        lastChangeCount = pasteboard.changeCount
    }

    func poll() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let frontmostBundleID, Defaults.excludedBundleIDs.contains(frontmostBundleID) {
            return
        }
        guard let content = ClipContent(
            pasteboard: pasteboard,
            ignoringConcealed: Defaults.ignoresConcealedContent,
            capturing: Defaults.captureOptions
        ) else { return }

        onNewContent?(content, frontmostBundleID)
    }
}
