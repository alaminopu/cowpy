import AppKit
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: HistoryStore?
    private var monitor: ClipboardMonitor?
    private var pasteService: PasteService?
    private var statusItemController: StatusItemController?
    private var expiryTimer: Timer?
    private var defaultsObserver: NSObjectProtocol?
    private lazy var settingsWindowController = SettingsWindowController()

    private let log = Logger(subsystem: "com.alamin.Cowpy", category: "App")

    /// Unit tests are hosted inside the app; they must not watch the real clipboard.
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningTests else { return }

        Defaults.register()
        NSApp.mainMenu = MainMenu.make(settingsTarget: self, settingsAction: #selector(showSettings))

        let store: HistoryStore
        do {
            store = try HistoryStore()
        } catch {
            presentFatalError("Cowpy could not open its history database.", error: error)
            return
        }

        let monitor = ClipboardMonitor()
        monitor.onNewContent = { [store] content, sourceBundleID in
            store.add(content, sourceBundleID: sourceBundleID)
            store.trim(to: Defaults.maxHistorySize)
        }

        let pasteService = PasteService(store: store, monitor: monitor)
        let statusItemController = StatusItemController(store: store, pasteService: pasteService)
        statusItemController.onShowSettings = { [weak self] in self?.showSettings() }

        let token = HotKeyCenter.shared.register(.defaultMainMenu) { [weak statusItemController] in
            statusItemController?.popUpAtCursor()
        }
        if token == nil {
            log.warning("⇧⌘V is already taken by another app; the global hotkey is disabled.")
        }

        monitor.start()

        self.store = store
        self.monitor = monitor
        self.pasteService = pasteService
        self.statusItemController = statusItemController

        removeExpiredClips()
        startExpiryTimer()
        observeSettings()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        if Defaults.clearsHistoryOnQuit {
            store?.clear()
        }
    }

    /// Opening Cowpy again while it is running (Finder, Spotlight, `open`) shows
    /// Settings. This is the way back in when the menu-bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showSettings()
        return false
    }

    @objc func showSettings() {
        settingsWindowController.show()
    }

    // MARK: - Settings changes

    private func observeSettings() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.settingsDidChange() }
        }
    }

    /// History limits are deliberately not enforced here: a smaller size applies
    /// at the next copy and a shorter retention at the next timer tick, so a
    /// slip in Settings can be undone before anything is deleted.
    private func settingsDidChange() {
        statusItemController?.applyVisibility()
    }

    // MARK: - Expiry

    private func startExpiryTimer() {
        // The shortest retention is an hour, so checking every few minutes is plenty.
        let timer = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.removeExpiredClips() }
        }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        expiryTimer = timer
    }

    private func removeExpiredClips() {
        guard let cutoff = Defaults.historyRetention.cutoff() else { return }
        store?.removeExpired(before: cutoff)
    }

    private func presentFatalError(_ message: String, error: Error) {
        log.fault("\(message) \(error)")
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.runModal()
        NSApp.terminate(nil)
    }
}
