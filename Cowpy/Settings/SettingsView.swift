import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            MenuSettingsView()
                .tabItem { Label("Menu", systemImage: "filemenu.and.selection") }
            HistorySettingsView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            CaptureSettingsView()
                .tabItem { Label("Capture", systemImage: "doc.on.clipboard") }
        }
        // One size for every tab keeps the window from jumping around; longer
        // forms scroll inside it.
        .frame(width: 500, height: 540)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @AppStorage(Defaults.Key.pastesAutomatically) private var pastesAutomatically = true
    @AppStorage(Defaults.Key.showsStatusItem) private var showsStatusItem = true

    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?
    @State private var isAccessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchesAtLogin)
                    .onChange(of: launchesAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Toggle("Show Cowpy in the menu bar", isOn: $showsStatusItem)
                LabeledContent("Open history", value: "⇧⌘V")
                LabeledContent("Open snippets", value: "⇧⌘B")
            } footer: {
                if !showsStatusItem {
                    Text("The shortcut still works. To get back to Settings, open Cowpy again from Applications or Spotlight.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Pasting") {
                Toggle("Paste into the active app after choosing a clip", isOn: $pastesAutomatically)
                if pastesAutomatically && !isAccessibilityTrusted {
                    HStack {
                        Label("Cowpy needs the Accessibility permission to paste for you.", systemImage: "exclamationmark.triangle")
                            .font(.callout)
                        Spacer()
                        Button("Open Settings…") { AccessibilityPermission.openSystemSettings() }
                    }
                }
            }

            Section("Hold a key while choosing a clip") {
                ForEach(ClipAction.allCases.filter { $0.modifierSymbols != nil }, id: \.self) { action in
                    LabeledContent(action.summary) {
                        Text(action.modifierSymbols ?? "")
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isAccessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        guard enabled != (SMAppService.mainApp.status == .enabled) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Menu

struct MenuSettingsView: View {
    @AppStorage(Defaults.Key.inlineItemCount) private var inlineItemCount = 10
    @AppStorage(Defaults.Key.itemsPerFolder) private var itemsPerFolder = 10
    @AppStorage(Defaults.Key.maxTitleLength) private var maxTitleLength = 50
    @AppStorage(Defaults.Key.showsThumbnails) private var showsThumbnails = true
    @AppStorage(Defaults.Key.showsColorSwatches) private var showsColorSwatches = true

    var body: some View {
        Form {
            Section("Layout") {
                Stepper("Show \(inlineItemCount) clips directly in the menu", value: $inlineItemCount, in: 0...30)
                Stepper("Group the rest \(itemsPerFolder) per submenu", value: $itemsPerFolder, in: 5...50, step: 5)
                Stepper("Truncate titles at \(maxTitleLength) characters", value: $maxTitleLength, in: 20...120, step: 10)
            }
            Section("Previews") {
                Toggle("Image thumbnails", isOn: $showsThumbnails)
                Toggle("Colour swatches for values like #ff8800 or rgb(255, 136, 0)", isOn: $showsColorSwatches)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - History

struct HistorySettingsView: View {
    @AppStorage(Defaults.Key.maxHistorySize) private var maxHistorySize = 100
    @AppStorage(Defaults.Key.historyRetention) private var historyRetention = HistoryRetention.forever.rawValue
    @AppStorage(Defaults.Key.clearsHistoryOnQuit) private var clearsHistoryOnQuit = false
    @AppStorage(Defaults.Key.confirmsBeforeClearing) private var confirmsBeforeClearing = true

    var body: some View {
        Form {
            Section {
                Stepper("Keep the last \(maxHistorySize) clips", value: $maxHistorySize, in: 10...1000, step: 10)
                Picker("Remove unused clips", selection: $historyRetention) {
                    ForEach(HistoryRetention.allCases) { retention in
                        Text(retention.label).tag(retention.rawValue)
                    }
                }
                Toggle("Clear history when Cowpy quits", isOn: $clearsHistoryOnQuit)
            } footer: {
                Text("Pinned clips are never trimmed, expired or cleared. A smaller limit takes effect the next time you copy something.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Ask before clearing history", isOn: $confirmsBeforeClearing)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Capture

struct CaptureSettingsView: View {
    @AppStorage(Defaults.Key.capturesText) private var capturesText = true
    @AppStorage(Defaults.Key.capturesRichText) private var capturesRichText = true
    @AppStorage(Defaults.Key.capturesImages) private var capturesImages = true
    @AppStorage(Defaults.Key.capturesPDFs) private var capturesPDFs = true
    @AppStorage(Defaults.Key.capturesFiles) private var capturesFiles = true
    @AppStorage(Defaults.Key.ignoresConcealedContent) private var ignoresConcealedContent = true

    var body: some View {
        Form {
            Section("Record") {
                Toggle("Text and links", isOn: $capturesText)
                Toggle("Text formatting (fonts, colours, HTML)", isOn: $capturesRichText)
                    .disabled(!capturesText)
                Toggle("Images", isOn: $capturesImages)
                Toggle("PDFs", isOn: $capturesPDFs)
                Toggle("Files and folders", isOn: $capturesFiles)
            }
            Section {
                Toggle("Skip passwords and other concealed content", isOn: $ignoresConcealedContent)
            } header: {
                Text("Privacy")
            } footer: {
                Text("Password managers mark what they copy as concealed. Cowpy never sends anything over the network.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
}
