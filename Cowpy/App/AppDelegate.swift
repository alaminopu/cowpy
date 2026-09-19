import AppKit
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: HistoryStore?
    private var snippetStore: SnippetStore?
    private var snippetsWindowController: SnippetsWindowController?
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
        let snippetStore: SnippetStore
        do {
            store = try HistoryStore()
            snippetStore = try SnippetStore()
        } catch {
            presentFatalError("Cowpy could not open its database.", error: error)
            return
        }

        let monitor = ClipboardMonitor()
        monitor.onNewContent = { [store] content, sourceBundleID in
            store.add(content, sourceBundleID: sourceBundleID)
            store.trim(to: Defaults.maxHistorySize)
        }

        let pasteService = PasteService(store: store, monitor: monitor)
        let statusItemController = StatusItemController(
            store: store,
            snippetStore: snippetStore,
            pasteService: pasteService
        )
        statusItemController.onShowSettings = { [weak self] in self?.showSettings() }
        statusItemController.onEditSnippets = { [weak self] in self?.showSnippetsEditor() }

        let hotKeys = HotKeyManager.shared
        hotKeys.handlers[.main] = { [weak statusItemController] combo in
            statusItemController?.popUpAtCursor(openedWith: combo)
        }
        hotKeys.handlers[.history] = { [weak statusItemController] combo in
            statusItemController?.popUpAtCursor(openedWith: combo, includesSnippets: false)
        }
        hotKeys.handlers[.snippets] = { [weak statusItemController] combo in
            statusItemController?.popUpSnippetsAtCursor(openedWith: combo)
        }
        hotKeys.start()
        for action in hotKeys.unavailable {
            log.warning("The shortcut for \(action.rawValue, privacy: .public) is taken by another app and is disabled.")
        }

        monitor.start()

        self.store = store
        self.snippetStore = snippetStore
        self.monitor = monitor
        self.pasteService = pasteService
        self.statusItemController = statusItemController

        removeExpiredClips()
        startExpiryTimer()
        observeSettings()

        // Handy when diagnosing "it stopped pasting": shows whether the grant survived an update.
        let isTrusted = AccessibilityPermission.isTrusted(prompt: false)
        log.notice("Accessibility permission granted: \(isTrusted, privacy: .public)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        snippetStore?.save()
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

    func showSnippetsEditor() {
        guard let snippetStore else { return }
        if snippetsWindowController == nil {
            snippetsWindowController = SnippetsWindowController(store: snippetStore)
        }
        snippetsWindowController?.show()
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
