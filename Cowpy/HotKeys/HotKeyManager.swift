import Carbon.HIToolbox
import Foundation
import Observation

/// The things a global shortcut can do.
nonisolated enum HotKeyAction: String, CaseIterable, Identifiable, Sendable {
    case main
    case history
    case snippets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main: "Open clips and snippets"
        case .history: "Open clips only"
        case .snippets: "Open snippets only"
        }
    }

    /// ⇧⌘V and ⇧⌘B are Clipy's defaults, so muscle memory carries over.
    var defaultCombo: KeyCombo? {
        switch self {
        case .main: KeyCombo(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(cmdKey | shiftKey))
        case .history: nil
        case .snippets: KeyCombo(keyCode: UInt32(kVK_ANSI_B), carbonModifiers: UInt32(cmdKey | shiftKey))
        }
    }

    var defaultsKey: String { "hotKey.\(rawValue)" }
}

/// Owns the user's shortcut choices: loads and saves them, keeps the system
/// registrations in sync, and reports conflicts.
@Observable
final class HotKeyManager {
    static let shared = HotKeyManager(registrar: HotKeyCenter.shared, defaults: .standard)

    enum SetResult: Equatable {
        case ok
        case usedBy(HotKeyAction)
        /// The system refused the registration, usually because another app owns the combo.
        case unavailable
    }

    private(set) var combos: [HotKeyAction: KeyCombo] = [:]
    /// Actions whose saved combo could not be registered at launch.
    private(set) var unavailable: Set<HotKeyAction> = []

    /// Called with the combo that fired, so the receiver knows which modifiers are still held.
    @ObservationIgnored var handlers: [HotKeyAction: (KeyCombo) -> Void] = [:]

    @ObservationIgnored private let registrar: HotKeyRegistering
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var tokens: [HotKeyAction: UInt32] = [:]
    @ObservationIgnored private var isPaused = false

    init(registrar: HotKeyRegistering, defaults: UserDefaults) {
        self.registrar = registrar
        self.defaults = defaults
    }

    /// Loads saved combos and registers them. Call once at launch.
    func start() {
        for action in HotKeyAction.allCases {
            combos[action] = storedCombo(for: action)
        }
        registerAll()
    }

    func set(_ combo: KeyCombo?, for action: HotKeyAction) -> SetResult {
        if let combo, let owner = combos.first(where: { $0.value == combo && $0.key != action })?.key {
            return .usedBy(owner)
        }

        let previous = combos[action]
        unregister(action)
        combos[action] = combo

        if let combo, !isPaused, !register(combo, for: action) {
            // Put the old shortcut back rather than leaving the action with none.
            combos[action] = previous
            if let previous { _ = register(previous, for: action) }
            return .unavailable
        }

        unavailable.remove(action)
        store(combo, for: action)
        return .ok
    }

    func restoreDefaults() {
        unregisterAll()
        for action in HotKeyAction.allCases {
            defaults.removeObject(forKey: action.defaultsKey)
            combos[action] = action.defaultCombo
        }
        if !isPaused { registerAll() }
    }

    /// While a shortcut is being recorded the existing ones must not fire,
    /// otherwise pressing ⇧⌘V to re-record it would open the history instead.
    func pause() {
        guard !isPaused else { return }
        isPaused = true
        unregisterAll()
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        registerAll()
    }

    // MARK: - Registration

    private func registerAll() {
        unavailable = []
        for (action, combo) in combos where tokens[action] == nil {
            if !register(combo, for: action) {
                unavailable.insert(action)
            }
        }
    }

    private func register(_ combo: KeyCombo, for action: HotKeyAction) -> Bool {
        let token = registrar.register(combo) { [weak self] in
            self?.handlers[action]?(combo)
        }
        tokens[action] = token
        return token != nil
    }

    private func unregister(_ action: HotKeyAction) {
        if let token = tokens.removeValue(forKey: action) {
            registrar.unregister(token)
        }
    }

    private func unregisterAll() {
        HotKeyAction.allCases.forEach(unregister)
    }

    // MARK: - Persistence

    /// Absent means "never customised" (use the default); empty data means
    /// the user cleared the shortcut on purpose.
    private func storedCombo(for action: HotKeyAction) -> KeyCombo? {
        guard let data = defaults.data(forKey: action.defaultsKey) else { return action.defaultCombo }
        return try? JSONDecoder().decode(KeyCombo.self, from: data)
    }

    private func store(_ combo: KeyCombo?, for action: HotKeyAction) {
        let data = combo.flatMap { try? JSONEncoder().encode($0) } ?? Data()
        defaults.set(data, forKey: action.defaultsKey)
    }
}
