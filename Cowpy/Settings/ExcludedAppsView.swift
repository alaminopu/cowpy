import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// An app Cowpy should not record copies from, identified by bundle ID.
struct ExcludedApp: Identifiable, Hashable {
    let bundleID: String
    var id: String { bundleID }

    /// `nil` when the app is no longer installed; the entry is kept anyway so
    /// reinstalling the app does not silently re-enable recording.
    var url: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    var name: String {
        guard let url else { return bundleID }
        return FileManager.default.displayName(atPath: url.path)
    }

    var icon: NSImage {
        let icon = url.map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSWorkspace.shared.icon(for: .applicationBundle)
        icon.size = NSSize(width: 20, height: 20)
        return icon
    }
}

/// Editor for the list of apps whose copies are never recorded.
struct ExcludedAppsSection: View {
    @State private var bundleIDs: [String] = UserDefaults.standard.stringArray(forKey: Defaults.Key.excludedBundleIDs) ?? []
    @State private var selection: String?

    var body: some View {
        Section {
            if bundleIDs.isEmpty {
                Text("No ignored apps")
                    .foregroundStyle(.secondary)
            } else {
                List(selection: $selection) {
                    ForEach(bundleIDs.map(ExcludedApp.init)) { app in
                        HStack {
                            Image(nsImage: app.icon)
                            Text(app.name)
                            Spacer()
                            if app.url == nil {
                                Text("not installed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(app.bundleID)
                    }
                }
                .frame(height: min(CGFloat(bundleIDs.count) * 30 + 8, 160))
            }

            HStack {
                Menu("Add Running App") {
                    ForEach(runningApps, id: \.bundleID) { app in
                        Button(app.name) { add([app.bundleID]) }
                    }
                }
                .fixedSize()
                Button("Choose…", action: chooseApps)
                Spacer()
                Button("Remove") {
                    if let selection { remove(selection) }
                }
                .disabled(selection == nil)
            }
        } header: {
            Text("Ignored apps")
        } footer: {
            Text("Nothing you copy while one of these apps is in front is recorded.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Regular (Dock) apps that are running and not already ignored.
    private var runningApps: [(bundleID: String, name: String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier, !bundleIDs.contains(bundleID) else { return nil }
                return (bundleID, app.localizedName ?? bundleID)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.message = "Choose apps Cowpy should ignore."
        guard panel.runModal() == .OK else { return }
        add(panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier })
    }

    private func add(_ newIDs: [String]) {
        bundleIDs = ExcludedAppList.adding(newIDs, to: bundleIDs)
        save()
    }

    private func remove(_ bundleID: String) {
        bundleIDs.removeAll { $0 == bundleID }
        selection = nil
        save()
    }

    private func save() {
        UserDefaults.standard.set(bundleIDs, forKey: Defaults.Key.excludedBundleIDs)
    }
}

nonisolated enum ExcludedAppList {
    /// Appends without duplicates and never adds Cowpy itself.
    static func adding(_ newIDs: [String], to existing: [String], ownBundleID: String? = Bundle.main.bundleIdentifier) -> [String] {
        var result = existing
        for id in newIDs where !result.contains(id) && id != ownBundleID {
            result.append(id)
        }
        return result
    }
}
