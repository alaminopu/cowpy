import SwiftUI

struct ShortcutsSettingsView: View {
    private let manager = HotKeyManager.shared

    var body: some View {
        Form {
            Section {
                ForEach(HotKeyAction.allCases) { action in
                    ShortcutRow(action: action, manager: manager)
                }
            } footer: {
                Text("Click a shortcut, then press the new keys. A shortcut needs ⌘, ⌃ or ⌥. Press ⌫ while recording to remove it, or ⎋ to cancel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Restore Defaults") { manager.restoreDefaults() }
                }
            }
        }
        .formStyle(.grouped)
        // Leaving the tab mid-recording must not leave the shortcuts switched off.
        .onDisappear { manager.resume() }
    }
}

private struct ShortcutRow: View {
    let action: HotKeyAction
    let manager: HotKeyManager

    @State private var isRecording = false
    @State private var message: String?
    @State private var eventMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(action.title) {
                HStack(spacing: 6) {
                    Button(action: toggleRecording) {
                        Text(buttonTitle)
                            .font(.body.monospaced())
                            .frame(minWidth: 96)
                    }
                    .buttonStyle(.bordered)
                    .tint(isRecording ? .accentColor : nil)

                    Button {
                        apply(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Remove this shortcut")
                    .opacity(manager.combos[action] == nil || isRecording ? 0 : 1)
                }
            }
            if let message = message ?? launchWarning {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private var buttonTitle: String {
        if isRecording { return "Press keys…" }
        return manager.combos[action]?.displayString ?? "None"
    }

    private var launchWarning: String? {
        manager.unavailable.contains(action) ? "Another app is using this shortcut, so it is switched off." : nil
    }

    // MARK: - Recording

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        message = nil
        isRecording = true
        manager.pause()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(RecorderInput(keyCode: Int(event.keyCode), modifiers: event.modifierFlags))
            return nil // swallow the key so it does not type or beep
        }
    }

    private func stopRecording() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
        guard isRecording else { return }
        isRecording = false
        manager.resume()
    }

    private func handle(_ input: RecorderInput) {
        switch input {
        case .cancel:
            stopRecording()
        case .clear:
            stopRecording()
            apply(nil)
        case .combo(let combo):
            stopRecording()
            apply(combo)
        case .rejected:
            message = "Add ⌘, ⌃ or ⌥ to the shortcut."
        }
    }

    private func apply(_ combo: KeyCombo?) {
        switch manager.set(combo, for: action) {
        case .ok:
            message = nil
        case .usedBy(let other):
            message = "\(combo?.displayString ?? "That") is already used for “\(other.title)”."
        case .unavailable:
            message = "\(combo?.displayString ?? "That") is taken by another app."
        }
    }
}
