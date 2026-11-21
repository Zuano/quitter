//
//  MenuBarContentView.swift
//  Quitter
//
//  The popover that appears when the user clicks the Q in the menu bar.
//  Shows a list of monitored apps with their status, plus pause/settings/quit.
//
//  Das Popover, das beim Klick auf das Q in der Menüleiste erscheint.
//  Zeigt die überwachten Apps mit Status sowie Pause/Einstellungen/Beenden.
//

import SwiftUI
import AppKit
import Combine

struct MenuBarContentView: View {
    @Bindable var monitor: AppMonitor

    // Lightweight ticker so the "in X min" countdowns refresh while popover is open
    // Kleiner Ticker, damit die "in X Min"-Anzeige sich live aktualisiert
    @State private var refreshTick: Date = .now
    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if monitor.monitoredApps.isEmpty {
                emptyState
            } else {
                appsList
            }

            Divider()

            footer
        }
        .frame(width: 320)
        .padding(.vertical, 8)
        .onReceive(ticker) { now in
            refreshTick = now
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "q.square.fill")
                .font(.title2)
            Text("Quitter")
                .font(.headline)
            Spacer()
            Toggle("Pause", isOn: $monitor.isPaused)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Noch keine Apps überwacht.")
                .foregroundStyle(.secondary)
            Button("Apps hinzufügen…") {
                openSettingsWindow()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var appsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(monitor.monitoredApps) { app in
                row(for: app)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                if app.id != monitor.monitoredApps.last?.id {
                    Divider().padding(.horizontal, 12)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for app: MonitoredApp) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body)
                Text(statusText(for: app))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Disabled apps look greyed out
            // Deaktivierte Apps werden ausgegraut
            if !app.isEnabled {
                Image(systemName: "pause.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(app.isEnabled ? 1.0 : 0.5)
        // refreshTick is read here so SwiftUI re-renders when it changes
        // refreshTick wird hier gelesen, damit SwiftUI bei Änderung neu rendert
        .id(refreshTick.timeIntervalSince1970.rounded())
    }

    private func statusText(for app: MonitoredApp) -> String {
        if !app.isEnabled { return "Deaktiviert" }
        if !monitor.isRunning(app) { return "Nicht gestartet" }
        if let remaining = monitor.remainingSeconds(for: app) {
            return "Beendet in \(formatRemaining(remaining))"
        }
        // Currently active in foreground
        // Aktuell aktiv im Vordergrund
        return "Aktiv – kein Timer"
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        if totalSeconds < 60 {
            return "\(totalSeconds) Sek"
        }
        let minutes = totalSeconds / 60
        return "\(minutes) Min"
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Button {
                openSettingsWindow()
            } label: {
                Label("Einstellungen…", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quitter beenden", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
    }

    /// Opens the Settings window and brings the app to the front,
    /// so the window is actually visible (menu bar apps don't activate by default).
    /// Öffnet das Einstellungsfenster und holt die App nach vorne,
    /// damit das Fenster sichtbar wird (Menüleisten-Apps aktivieren sich sonst nicht).
    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }
}
