//
//  AppPickerView.swift
//  Quitter
//
//  Modal sheet to pick an installed app and add it to the monitor list.
//  Lists everything from /Applications etc., with a search field.
//
//  Modaler Dialog zur Auswahl einer installierten App, die zur
//  Überwachungsliste hinzugefügt wird. Listet alles aus /Applications etc.,
//  mit Suchfeld.
//

import SwiftUI
import AppKit

struct AppPickerView: View {
    let monitor: AppMonitor
    @Environment(\.dismiss) private var dismiss

    @State private var allApps: [InstalledApp] = []
    @State private var searchText: String = ""
    @State private var selection: InstalledApp.ID?
    @State private var defaultTimeoutMinutes: Int = 5

    var filteredApps: [InstalledApp] {
        // Hide already-monitored apps
        // Bereits überwachte Apps ausblenden
        let alreadyMonitored = Set(monitor.monitoredApps.map { $0.bundleIdentifier })
        let pool = allApps.filter { !alreadyMonitored.contains($0.bundleIdentifier) }

        guard !searchText.isEmpty else { return pool }
        return pool.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("App auswählen")
                    .font(.headline)
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Divider()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Suchen…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            List(selection: $selection) {
                ForEach(filteredApps) { app in
                    HStack {
                        Image(nsImage: app.icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                        VStack(alignment: .leading) {
                            Text(app.name)
                            Text(app.bundleIdentifier)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(app.id)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Divider()

            HStack {
                Text("Standard-Timeout:")
                TextField("Min", value: $defaultTimeoutMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                Text("Min")
                Spacer()
                Button("Hinzufügen") {
                    addSelected()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection == nil)
            }
            .padding()
        }
        .frame(width: 520, height: 480)
        .task {
            // Load apps off the main actor – disk scan can take a moment
            // Apps im Hintergrund laden – Scan kann kurz dauern
            let scanned = await Task.detached(priority: .userInitiated) {
                AppLibrary.scanInstalledApps()
            }.value
            allApps = scanned
        }
    }

    private func addSelected() {
        guard let selectedID = selection,
              let chosen = allApps.first(where: { $0.id == selectedID }) else { return }

        let newEntry = MonitoredApp(
            bundleIdentifier: chosen.bundleIdentifier,
            name: chosen.name,
            path: chosen.path,
            timeoutMinutes: max(1, defaultTimeoutMinutes),
            isEnabled: true
        )
        monitor.add(newEntry)
        dismiss()
    }
}
