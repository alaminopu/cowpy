import Foundation

/// Typed access to user preferences. Views bind to the same keys with `@AppStorage`.
enum Defaults {
    enum Key {
        static let maxHistorySize = "maxHistorySize"
        static let inlineItemCount = "inlineItemCount"
        static let itemsPerFolder = "itemsPerFolder"
        static let maxTitleLength = "maxTitleLength"
        static let pastesAutomatically = "pastesAutomatically"
        static let showsThumbnails = "showsThumbnails"
        static let showsColorSwatches = "showsColorSwatches"
        static let showsStatusItem = "showsStatusItem"
        static let ignoresConcealedContent = "ignoresConcealedContent"
        static let excludedBundleIDs = "excludedBundleIDs"
        static let confirmsBeforeClearing = "confirmsBeforeClearing"
        static let clearsHistoryOnQuit = "clearsHistoryOnQuit"
        static let historyRetention = "historyRetention"
        static let capturesText = "capturesText"
        static let capturesRichText = "capturesRichText"
        static let capturesImages = "capturesImages"
        static let capturesPDFs = "capturesPDFs"
        static let capturesFiles = "capturesFiles"
    }

    static func register(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            Key.maxHistorySize: 100,
            Key.inlineItemCount: 10,
            Key.itemsPerFolder: 10,
            Key.maxTitleLength: 50,
            Key.pastesAutomatically: true,
            Key.showsThumbnails: true,
            Key.showsColorSwatches: true,
            Key.showsStatusItem: true,
            Key.ignoresConcealedContent: true,
            Key.excludedBundleIDs: [String](),
            Key.confirmsBeforeClearing: true,
            Key.clearsHistoryOnQuit: false,
            Key.historyRetention: HistoryRetention.forever.rawValue,
            Key.capturesText: true,
            Key.capturesRichText: true,
            Key.capturesImages: true,
            Key.capturesPDFs: true,
            Key.capturesFiles: true,
        ])
    }

    private static var store: UserDefaults { .standard }

    static var maxHistorySize: Int { max(1, store.integer(forKey: Key.maxHistorySize)) }
    static var inlineItemCount: Int { max(0, store.integer(forKey: Key.inlineItemCount)) }
    static var itemsPerFolder: Int { max(1, store.integer(forKey: Key.itemsPerFolder)) }
    static var maxTitleLength: Int { max(10, store.integer(forKey: Key.maxTitleLength)) }
    static var pastesAutomatically: Bool { store.bool(forKey: Key.pastesAutomatically) }
    static var showsThumbnails: Bool { store.bool(forKey: Key.showsThumbnails) }
    static var showsColorSwatches: Bool { store.bool(forKey: Key.showsColorSwatches) }
    static var showsStatusItem: Bool { store.bool(forKey: Key.showsStatusItem) }
    static var ignoresConcealedContent: Bool { store.bool(forKey: Key.ignoresConcealedContent) }
    static var excludedBundleIDs: Set<String> {
        Set(store.stringArray(forKey: Key.excludedBundleIDs) ?? [])
    }

    static var confirmsBeforeClearing: Bool {
        get { store.bool(forKey: Key.confirmsBeforeClearing) }
        set { store.set(newValue, forKey: Key.confirmsBeforeClearing) }
    }
    static var clearsHistoryOnQuit: Bool { store.bool(forKey: Key.clearsHistoryOnQuit) }
    static var historyRetention: HistoryRetention {
        HistoryRetention(rawValue: store.integer(forKey: Key.historyRetention)) ?? .forever
    }

    static var captureOptions: CaptureOptions {
        var options: CaptureOptions = []
        if store.bool(forKey: Key.capturesText) { options.insert(.text) }
        if store.bool(forKey: Key.capturesRichText) { options.insert(.richText) }
        if store.bool(forKey: Key.capturesImages) { options.insert(.images) }
        if store.bool(forKey: Key.capturesPDFs) { options.insert(.pdfs) }
        if store.bool(forKey: Key.capturesFiles) { options.insert(.files) }
        return options
    }
}

/// How long unpinned clips are kept. Raw value is the age limit in seconds.
nonisolated enum HistoryRetention: Int, CaseIterable, Identifiable, Sendable {
    case forever = 0
    case oneHour = 3600
    case oneDay = 86400
    case oneWeek = 604_800
    case oneMonth = 2_592_000

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .forever: "Never"
        case .oneHour: "After an hour"
        case .oneDay: "After a day"
        case .oneWeek: "After a week"
        case .oneMonth: "After 30 days"
        }
    }

    /// Clips last used before this date have expired; `nil` means nothing expires.
    func cutoff(from now: Date = .now) -> Date? {
        self == .forever ? nil : now.addingTimeInterval(-TimeInterval(rawValue))
    }
}
