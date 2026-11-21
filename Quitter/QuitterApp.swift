//
//  QuitterApp.swift
//  Quitter
//
//  App entry point – uses MenuBarExtra to live as a menu bar app only.
//  App-Einstiegspunkt – läuft als reine Menüleisten-App via MenuBarExtra.
//

import SwiftUI

@main
struct QuitterApp: App {
    // Single shared monitor for the whole app
    // Ein gemeinsamer Monitor für die ganze App
    @State private var monitor = AppMonitor()

    var body: some Scene {
        // The "q.square.fill" SF Symbol shows up in the menu bar
        // Das SF-Symbol "q.square.fill" erscheint oben in der Menüleiste
        MenuBarExtra {
            MenuBarContentView(monitor: monitor)
        } label: {
            Image(systemName: "q.square.fill")
        }
        .menuBarExtraStyle(.window) // window-style popover, not classic menu
        // Fenster-Stil (Popover), nicht das klassische macOS-Menü

        // Settings window – opens via "Einstellungen…" entry in popover
        // Einstellungsfenster – öffnet sich über "Einstellungen…" im Popover
        Settings {
            SettingsView(monitor: monitor)
        }
    }
}
