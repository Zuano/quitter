//
//  MonitoredApp.swift
//  Quitter
//
//  Data model for an app being monitored by Quitter.
//  Datenmodell für eine App, die von Quitter überwacht wird.
//

import Foundation

struct MonitoredApp: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    /// Bundle identifier, e.g. "com.apple.Safari"
    /// Bundle-ID, z.B. "com.apple.Safari"
    var bundleIdentifier: String

    /// Display name shown to the user
    /// Anzeigename für den User
    var name: String

    /// Path to the .app bundle, used to load the icon
    /// Pfad zur .app, damit wir das Icon laden können
    var path: String

    /// Inactivity timeout in minutes
    /// Inaktivitäts-Zeit in Minuten
    var timeoutMinutes: Int

    /// Whether monitoring is enabled for this app
    /// Ob die Überwachung für diese App aktiv ist
    var isEnabled: Bool = true
}
