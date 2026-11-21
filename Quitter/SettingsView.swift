//
//  SettingsView.swift
//  Quitter
//
//  Settings window: list of monitored apps with edit/delete, plus an "Add" button
//  that opens the AppPickerView.
//
//  Einstellungsfenster: Liste der überwachten Apps mit Bearbeiten/Löschen,
//  plus "Hinzufügen"-Knopf, der den AppPickerView öffnet.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @Bindable var monitor: AppMonitor
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Überwachte Apps")
                    .font(.title2)
                    .bold()
                Spacer()
                Button {
                    showingPicker = true
                } label: {
                    Label("Hinzufügen", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            if monitor.monitoredApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Noch keine Apps in der Liste.")
                        .foregroundStyle(.secondary)
                    Text("Klick auf 'Hinzufügen', um eine App auszuwählen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($monitor.monitoredApps) { $app in
                        AppEditorRow(app: $app, monitor: monitor)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(width: 560, height: 420)
        .sheet(isPresented: $showingPicker) {
            AppPickerView(monitor: monitor)
        }
    }
}

/// One row in the settings list – icon, name, timeout field, on/off toggle, delete.
/// Eine Zeile in der Liste – Icon, Name, Timeout-Feld, An/Aus-Schalter, Löschen.
struct AppEditorRow: View {
    @Binding var app: MonitoredApp
    let monitor: AppMonitor

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable()
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body)
                Text(app.bundleIdentifier)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text("Beenden nach")
                    .font(.caption)
                TextField(
                    "Min",
                    value: $app.timeoutMinutes,
                    format: .number
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                Text("Min")
                    .font(.caption)
            }

            Toggle("", isOn: $app.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()

            Button(role: .destructive) {
                monitor.remove(app)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        // Persist whenever any field on this row changes
        // Speichern, sobald sich an dieser Zeile etwas ändert
        .onChange(of: app) { _, _ in
            monitor.persist()
        }
    }
}
